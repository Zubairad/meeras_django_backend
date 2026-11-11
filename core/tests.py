from django.test import TestCase
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework import status

from core.models import (
    User, HelpRequest, Inventory, InventoryLog, Personnel,
    Broadcast, ChatMessage, DisasterZone, Shelter
)
from core.ai_service import DisasterRiskPredictor
from core.routing_service import DisasterAwareRoutingEngine


class MeerasBackendTestSuite(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Create system admin
        self.admin = User.objects.create_superuser(
            username='sysadmin', email='admin@meeras.org', password='password123',
            role='system_admin'
        )

        # Create verified NGO admin
        self.ngo_admin = User.objects.create_user(
            username='edhi_admin', email='edhi@meeras.org', password='password123',
            role='ngo_admin', organization_name='Edhi Foundation', is_verified_ngo=True
        )

        # Create unverified NGO admin
        self.unverified_ngo = User.objects.create_user(
            username='new_ngo', email='new@ngo.org', password='password123',
            role='ngo_admin', organization_name='New Relief NGO', is_verified_ngo=False
        )

        # Create helper
        self.helper = User.objects.create_user(
            username='ali_helper', email='ali@meeras.org', password='password123',
            role='helper'
        )

        # Create citizen / victim
        self.citizen = User.objects.create_user(
            username='victim1', email='victim1@gmail.com', password='password123',
            role='citizen'
        )

    # -------------------------------------------------------------------------
    # 1. AUTHENTICATION & SECURITY TESTS
    # -------------------------------------------------------------------------
    def test_registration_prevents_system_admin_escalation(self):
        """Privilege escalation check: regular registration must reject system_admin role."""
        payload = {
            'username': 'hacker',
            'email': 'hacker@meeras.org',
            'password': 'StrongPassword123',
            'role': 'system_admin'
        }
        res = self.client.post('/api/users/', payload)
        self.assertEqual(res.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('Cannot register as System Administrator', str(res.data))

    def test_ngo_admin_starts_unverified(self):
        """NGO accounts must register in unverified state awaiting admin review (FR 1.3)."""
        payload = {
            'username': 'al_khidmat',
            'email': 'alkhidmat@meeras.org',
            'password': 'StrongPassword123',
            'role': 'ngo_admin',
            'organization_name': 'Al Khidmat Foundation'
        }
        res = self.client.post('/api/users/', payload)
        self.assertEqual(res.status_code, status.HTTP_201_CREATED)
        new_user = User.objects.get(username='al_khidmat')
        self.assertFalse(new_user.is_verified_ngo)

    def test_admin_can_verify_ngo(self):
        """Admin endpoint to approve pending NGO accounts (FR 10.2)."""
        self.client.force_authenticate(user=self.admin)
        res = self.client.post(f'/api/users/{self.unverified_ngo.id}/verify_ngo/')
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        self.unverified_ngo.refresh_from_db()
        self.assertTrue(self.unverified_ngo.is_verified_ngo)

    # -------------------------------------------------------------------------
    # 2. HELP REQUEST WORKFLOW & RACE CONDITION TESTS
    # -------------------------------------------------------------------------
    def test_help_request_creation_and_atomic_assignment(self):
        """Tests request submission, helper self-assignment, and double-assignment conflict."""
        self.client.force_authenticate(user=self.citizen)
        req_res = self.client.post('/api/help-requests/', {
            'title': 'Family stranded on roof',
            'description': 'Water levels rising rapidly in Rajanpur sector 3',
            'location': 'Rajanpur Sector 3',
            'latitude': 29.1035,
            'longitude': 70.3250,
            'urgency': 5,
            'people_affected': 6
        })
        self.assertEqual(req_res.status_code, status.HTTP_201_CREATED)
        req_id = req_res.data['id']

        # Helper 1 accepts request
        self.client.force_authenticate(user=self.helper)
        assign_res = self.client.patch(f'/api/help-requests/{req_id}/assign/')
        self.assertEqual(assign_res.status_code, status.HTTP_200_OK)
        self.assertEqual(assign_res.data['status'], 'assigned')

        # Helper 2 attempts to accept already assigned request -> 409 Conflict
        helper2 = User.objects.create_user(username='helper2', password='password123', role='helper')
        self.client.force_authenticate(user=helper2)
        conflict_res = self.client.patch(f'/api/help-requests/{req_id}/assign/')
        self.assertEqual(conflict_res.status_code, status.HTTP_409_CONFLICT)

    def test_help_request_completion(self):
        """Only assigned helper, creator, or admin can mark a ticket completed."""
        hr = HelpRequest.objects.create(
            title='Need emergency ration', description='Food running low',
            location='Nowshera', urgency=3, created_by=self.citizen,
            assigned_to=self.helper, status='assigned'
        )

        # Random user cannot complete
        random_user = User.objects.create_user(username='random', password='password123', role='citizen')
        self.client.force_authenticate(user=random_user)
        res = self.client.patch(f'/api/help-requests/{hr.id}/complete/')
        self.assertEqual(res.status_code, status.HTTP_403_FORBIDDEN)

        # Assigned helper can complete
        self.client.force_authenticate(user=self.helper)
        comp_res = self.client.patch(f'/api/help-requests/{hr.id}/complete/')
        self.assertEqual(comp_res.status_code, status.HTTP_200_OK)
        hr.refresh_from_db()
        self.assertEqual(hr.status, 'completed')
        self.assertIsNotNone(hr.resolved_at)

    # -------------------------------------------------------------------------
    # 3. INVENTORY & PERSONNEL TESTS
    # -------------------------------------------------------------------------
    def test_inventory_creation_and_stock_adjust_log(self):
        """Tests inventory management, stock decrement, and audit log generation."""
        self.client.force_authenticate(user=self.ngo_admin)
        inv_res = self.client.post('/api/inventory/', {
            'item_name': 'Chlorine Water Purification Tablets',
            'category': 'Water',
            'quantity': 500,
            'low_stock_threshold': 50,
            'unit': 'boxes'
        })
        self.assertEqual(inv_res.status_code, status.HTTP_201_CREATED)
        item_id = inv_res.data['id']

        # Adjust stock (dispatch 460 boxes) -> Triggers low stock alert
        adj_res = self.client.post(f'/api/inventory/{item_id}/adjust_stock/', {
            'delta': -460,
            'reason': 'Dispatched to R.Y. Khan relief camps'
        })
        self.assertEqual(adj_res.status_code, status.HTTP_200_OK)
        self.assertEqual(adj_res.data['item']['quantity'], 40)
        self.assertTrue(adj_res.data['low_stock_alert'])

        # Low stock endpoint test (optimized ORM filter)
        low_res = self.client.get('/api/inventory/low_stock/')
        self.assertEqual(low_res.status_code, status.HTTP_200_OK)
        self.assertEqual(len(low_res.data), 1)

    # -------------------------------------------------------------------------
    # 4. BROADCASTS & MISINFORMATION MODERATION TESTS
    # -------------------------------------------------------------------------
    def test_broadcast_flagging_and_admin_verification(self):
        """Tests posting, user flagging, auto-escalation to 'flagged', and admin verification."""
        self.client.force_authenticate(user=self.citizen)
        b_res = self.client.post('/api/broadcasts/', {
            'message': 'Dam has collapsed! Water coming right now!',
            'location': 'Taunsa Barrage'
        })
        self.assertEqual(b_res.status_code, status.HTTP_201_CREATED)
        b_id = b_res.data['id']

        # 3 users flag the post as spreading panic
        for i in range(3):
            u = User.objects.create_user(username=f'flagger_{i}', password='password123')
            self.client.force_authenticate(user=u)
            self.client.post(f'/api/broadcasts/{b_id}/flag/', {'reason': 'Spreading panic unnecessarily'})

        broadcast = Broadcast.objects.get(pk=b_id)
        self.assertEqual(broadcast.flag_count, 3)
        self.assertEqual(broadcast.status, 'flagged')

        # Admin reviews and resets/verifies
        self.client.force_authenticate(user=self.admin)
        v_res = self.client.post(f'/api/broadcasts/{b_id}/verify/')
        self.assertEqual(v_res.status_code, status.HTTP_200_OK)
        broadcast.refresh_from_db()
        self.assertEqual(broadcast.status, 'verified')

    # -------------------------------------------------------------------------
    # 5. DISASTER-AWARE ROUTING ENGINE TESTS
    # -------------------------------------------------------------------------
    def test_dijkstra_safe_route_hazard_avoidance(self):
        """Routing test: When R.Y. Khan has a Critical flood zone, router bypasses it via Cholistan."""
        DisasterZone.objects.create(
            name='Indus Flood Inundation - R.Y. Khan',
            disaster_type='Flood',
            risk_level='Critical',
            latitude=28.4212,
            longitude=70.2989,
            radius_km=25.0,
            is_active=True
        )

        self.client.force_authenticate(user=self.citizen)
        res = self.client.post('/api/routes/safe-route/', {
            'start': 'SUKKUR',
            'destination': 'MULTAN'
        })
        self.assertEqual(res.status_code, status.HTTP_200_OK)
        path = res.data['path']

        # Ensure flooded R_Y_KHAN was avoided
        self.assertNotIn('R_Y_KHAN', path)
        self.assertIn('CHOLISTAN_CORRIDOR', path)
        self.assertIn('BAHAWALPUR', path)
        self.assertEqual(path[-1], 'MULTAN')
        self.assertFalse(res.data['hazard_warning'])

    def test_routing_fallback_least_risk_mode(self):
        """If all roads are blocked by critical hazards, router provides least-risk alternative with hazard warning (FR 8.6)."""
        # Block both corridors
        DisasterZone.objects.create(name='Z1', risk_level='Critical', latitude=28.4212, longitude=70.2989, radius_km=30.0, is_active=True)
        DisasterZone.objects.create(name='Z2', risk_level='Critical', latitude=28.7500, longitude=71.3000, radius_km=30.0, is_active=True)

        res = DisasterAwareRoutingEngine.calculate_safe_route('SUKKUR', 'MULTAN')
        self.assertTrue(res['success'])
        self.assertTrue(res['hazard_warning'])
        self.assertIn('CAUTION', res['note'])

    # -------------------------------------------------------------------------
    # 6. AI DISASTER PREDICTION & FAILURE DETECTION TESTS
    # -------------------------------------------------------------------------
    def test_ai_disaster_risk_prediction_with_pmd_data(self):
        """Predicts flood risk using Rahim Yar Khan August 2024 monsoon parameters."""
        payload = {
            'station': 'R.Y.KHAN',
            'month': 8,
            'temp_max': 36.5,
            'temp_min': 27.7,
            'rainfall_mm': 258.2,
            'description': 'Heavy continuous monsoon downpour, low lying areas waterlogged'
        }
        res = DisasterRiskPredictor.predict(payload)
        self.assertIn(res['risk_level'], ['High', 'Critical'])
        self.assertTrue(res['evacuation_warning'])
        self.assertGreaterEqual(res['probability'], 0.50)

    def test_ai_predictor_failure_detection_and_heuristic_fallback(self):
        """Validates that corrupt or missing models cleanly fall back to hydrological threshold heuristics without crashing."""
        # Pass missing / extreme data
        payload = {
            'station': 'UNKNOWN_VALLEY',
            'month': 7,
            'rainfall_mm': 180.0
        }
        res = DisasterRiskPredictor.predict(payload)
        self.assertIn(res['risk_level'], ['High', 'Critical'])
        self.assertGreaterEqual(res['probability'], 0.60)
