from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny
from django_filters.rest_framework import DjangoFilterBackend
from django.db import transaction, models
from django.utils import timezone

from .models import (
    User, HelpRequest, Inventory, InventoryLog, Personnel,
    Broadcast, ChatMessage, DisasterZone, Shelter, AuditLog
)
from .serializers import (
    UserSerializer, UserRegistrationSerializer, HelpRequestSerializer,
    InventorySerializer, InventoryLogSerializer, PersonnelSerializer,
    BroadcastSerializer, ChatSerializer, DisasterZoneSerializer,
    ShelterSerializer, AuditLogSerializer
)
from .permissions import (
    IsActiveAndUnblocked, IsSystemAdmin, IsNGOAdmin,
    IsNGOAdminOrReadOnly, IsOwnerOrAdminOrReadOnly
)
from .ai_service import DisasterRiskPredictor
from .routing_service import DisasterAwareRoutingEngine


# ==========================================
# REUSABLE MIXIN TO ELIMINATE REPETITIVE CODE
# ==========================================
class NGORelatedViewSet(viewsets.ModelViewSet):
    """
    DRY Base ViewSet for resources owned by an NGO (Inventory, Personnel).
    - Automatically scopes queries: NGO admins see their own; helpers/citizens view all.
    - Automatically injects `ngo=request.user` on creation.
    """
    permission_classes = [IsActiveAndUnblocked, IsNGOAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    search_fields = ['name'] if hasattr(Personnel, 'name') else ['item_name']

    def get_queryset(self):
        user = self.request.user
        qs = getattr(self, 'base_queryset', self.queryset)
        if user.is_authenticated and user.role == 'ngo_admin':
            return qs.filter(ngo=user)
        return qs

    def perform_create(self, serializer):
        serializer.save(ngo=self.request.user)


# ==========================================
# USER & AUTH MANAGEMENT
# ==========================================
class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsActiveAndUnblocked]
    filter_backends = [filters.SearchFilter]
    search_fields = ['username', 'email', 'role', 'organization_name']

    def get_serializer_class(self):
        if self.action == 'create':
            return UserRegistrationSerializer
        return UserSerializer

    def get_permissions(self):
        if self.action == 'create':
            return [AllowAny()]
        return super().get_permissions()

    def get_queryset(self):
        user = self.request.user
        # System admins can view all accounts; others can view only active/unblocked users
        if user.is_superuser or user.role == 'system_admin':
            return User.objects.all()
        return User.objects.filter(is_blocked=False)

    @action(detail=False, methods=['get'])
    def me(self, request):
        """Return the authenticated user's profile."""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[IsSystemAdmin])
    def verify_ngo(self, request, pk=None):
        """Administrator action: verify and approve an NGO account (FR 1.3, FR 10.2)."""
        target_user = self.get_object()
        if target_user.role != 'ngo_admin':
            return Response({'error': 'Only users with the ngo_admin role can be verified.'}, status=status.HTTP_400_BAD_REQUEST)
        target_user.is_verified_ngo = True
        target_user.save(update_fields=['is_verified_ngo'])

        AuditLog.objects.create(
            actor=request.user,
            action='NGO_VERIFIED',
            target_model='User',
            target_id=str(target_user.id),
            details=f"Approved NGO account for {target_user.organization_name or target_user.username}"
        )
        return Response({'status': 'NGO organization approved and verified successfully.', 'user': UserSerializer(target_user).data})

    @action(detail=True, methods=['post'], permission_classes=[IsSystemAdmin])
    def block_user(self, request, pk=None):
        """Administrator action: block/suspend a malicious user (FR 10.5, UC 10.4)."""
        target_user = self.get_object()
        if target_user.is_superuser or target_user.role == 'system_admin':
            return Response({'error': 'Cannot block a system administrator.'}, status=status.HTTP_400_BAD_REQUEST)
        
        target_user.is_blocked = True
        target_user.save(update_fields=['is_blocked'])

        AuditLog.objects.create(
            actor=request.user,
            action='USER_BLOCKED',
            target_model='User',
            target_id=str(target_user.id),
            details=f"Blocked user account {target_user.username}"
        )
        return Response({'status': f"User {target_user.username} has been blocked."})


# ==========================================
# HELP REQUESTS (CRISIS TICKETS)
# ==========================================
class HelpRequestViewSet(viewsets.ModelViewSet):
    queryset = HelpRequest.objects.select_related('assigned_to', 'created_by').all()
    serializer_class = HelpRequestSerializer
    permission_classes = [IsActiveAndUnblocked]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'urgency', 'assigned_to']
    search_fields = ['title', 'description', 'location']
    ordering_fields = ['created_at', 'urgency']
    ordering = ['-created_at']

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @action(detail=True, methods=['patch'], permission_classes=[IsActiveAndUnblocked])
    def assign(self, request, pk=None):
        """
        Assign a helper to a help request (FR 5.3).
        Uses atomic select_for_update to prevent race conditions when two helpers accept simultaneously.
        """
        with transaction.atomic():
            help_request = HelpRequest.objects.select_for_update().get(pk=pk)

            # Check if already assigned (Sequence Diagram Figure 3.30 alt [Already assigned])
            if help_request.status == 'assigned' and help_request.assigned_to is not None:
                return Response(
                    {'error': 'This help request is already assigned to another responder.'},
                    status=status.HTTP_409_CONFLICT
                )

            helper_id = request.data.get('assigned_to')
            # If helper accepts directly, assign to themselves
            if not helper_id and request.user.role == 'helper':
                helper = request.user
            elif helper_id:
                try:
                    helper = User.objects.get(pk=helper_id, role='helper', is_blocked=False)
                except User.DoesNotExist:
                    return Response({'error': 'Helper not found or invalid.'}, status=status.HTTP_404_NOT_FOUND)
            else:
                return Response({'error': 'assigned_to helper ID is required.'}, status=status.HTTP_400_BAD_REQUEST)

            help_request.assigned_to = helper
            help_request.status = 'assigned'
            help_request.save()

            AuditLog.objects.create(
                actor=request.user,
                action='HELP_REQUEST_ASSIGNED',
                target_model='HelpRequest',
                target_id=str(help_request.id),
                details=f"Assigned to helper {helper.username}"
            )
            return Response(self.get_serializer(help_request).data)

    @action(detail=True, methods=['patch'])
    def complete(self, request, pk=None):
        """Mark a help request as resolved/completed (FR 5.4, UC 6.3)."""
        help_request = self.get_object()
        
        # Verify authorization: only assigned helper, ticket creator, or admin can complete
        user = request.user
        if not (user.is_superuser or user.role == 'system_admin' or user.role == 'ngo_admin' or 
                help_request.assigned_to == user or help_request.created_by == user):
            return Response({'error': 'Permission denied. Only assigned responders or creators can resolve this request.'}, status=status.HTTP_403_FORBIDDEN)

        if help_request.status == 'completed':
            return Response({'message': 'Request is already marked as completed.'})

        help_request.status = 'completed'
        help_request.resolved_at = timezone.now()
        help_request.save()

        # Free any assigned personnel linked to this request
        Personnel.objects.filter(assigned_request=help_request).update(assigned_request=None, available=True)

        return Response(self.get_serializer(help_request).data)

    @action(detail=True, methods=['patch'])
    def cancel(self, request, pk=None):
        """Cancel an open request (UC 6.2)."""
        help_request = self.get_object()
        if help_request.status in ('completed', 'cancelled'):
            return Response({'error': 'Cannot cancel an already closed request.'}, status=status.HTTP_400_BAD_REQUEST)

        help_request.status = 'cancelled'
        help_request.save(update_fields=['status'])
        return Response(self.get_serializer(help_request).data)


# ==========================================
# INVENTORY MANAGEMENT
# ==========================================
class InventoryViewSet(NGORelatedViewSet):
    queryset = Inventory.objects.select_related('ngo').prefetch_related('logs').all()
    base_queryset = queryset
    serializer_class = InventorySerializer

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        """
        Database-level optimized filter for items at or below low_stock_threshold (FR 7.5).
        Replaces the inefficient in-memory loop.
        """
        qs = self.get_queryset().filter(quantity__lte=models.F('low_stock_threshold'))
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def adjust_stock(self, request, pk=None):
        """
        Records inventory usage or restocking with automatic audit trail (FR 7.4).
        Payload: { "delta": -25, "reason": "Distributed to flood relief camp" }
        """
        item = self.get_object()
        try:
            delta = int(request.data.get('delta', 0))
        except (ValueError, TypeError):
            return Response({'error': 'Valid integer delta is required.'}, status=status.HTTP_400_BAD_REQUEST)

        reason = request.data.get('reason', 'Routine stock adjustment')
        new_quantity = item.quantity + delta
        if new_quantity < 0:
            return Response({'error': f"Insufficient stock. Available: {item.quantity}, requested deduction: {abs(delta)}"}, status=status.HTTP_400_BAD_REQUEST)

        item.quantity = new_quantity
        item.save(update_fields=['quantity'])

        # Create history log
        log = InventoryLog.objects.create(
            item=item,
            change_quantity=delta,
            balance_after=new_quantity,
            reason=reason,
            logged_by=request.user
        )

        return Response({
            'item': self.get_serializer(item).data,
            'log': InventoryLogSerializer(log).data,
            'low_stock_alert': item.is_low_stock
        })


# ==========================================
# PERSONNEL MANAGEMENT
# ==========================================
class PersonnelViewSet(NGORelatedViewSet):
    queryset = Personnel.objects.select_related('ngo', 'assigned_request').all()
    base_queryset = queryset
    serializer_class = PersonnelSerializer

    @action(detail=True, methods=['post'])
    def assign_to_request(self, request, pk=None):
        """Assign an active personnel member to a HelpRequest (FR 6.4, UC 7.5)."""
        person = self.get_object()
        request_id = request.data.get('help_request_id')
        if not request_id:
            return Response({'error': 'help_request_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            help_request = HelpRequest.objects.get(pk=request_id)
        except HelpRequest.DoesNotExist:
            return Response({'error': 'Help request not found.'}, status=status.HTTP_404_NOT_FOUND)

        person.assigned_request = help_request
        person.available = False
        person.save(update_fields=['assigned_request', 'available'])

        return Response(self.get_serializer(person).data)

    @action(detail=True, methods=['post'])
    def release(self, request, pk=None):
        """Release personnel back to available roster."""
        person = self.get_object()
        person.assigned_request = None
        person.available = True
        person.save(update_fields=['assigned_request', 'available'])
        return Response(self.get_serializer(person).data)


# ==========================================
# BROADCASTS & COMMUNITY FEED (MISINFORMATION)
# ==========================================
class BroadcastViewSet(viewsets.ModelViewSet):
    queryset = Broadcast.objects.select_related('posted_by').all()
    serializer_class = BroadcastSerializer
    permission_classes = [IsActiveAndUnblocked]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'is_urgent']
    search_fields = ['message', 'location', 'flag_reason']
    ordering_fields = ['created_at', 'flag_count']
    ordering = ['-created_at']

    def get_permissions(self):
        if self.action in ('update', 'partial_update', 'destroy'):
            return [IsActiveAndUnblocked(), IsOwnerOrAdminOrReadOnly()]
        return [IsActiveAndUnblocked()]

    def perform_create(self, serializer):
        serializer.save(posted_by=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[IsActiveAndUnblocked])
    def flag(self, request, pk=None):
        """
        Flag a suspicious post (UC 4.2 / prototype screenshot).
        Any authenticated user can flag false or panic-inducing reports.
        Payload: { "reason": "Spreading panic unnecessarily" }
        """
        broadcast = self.get_object()
        reason = request.data.get('reason', 'Suspected misinformation')
        broadcast.flag_count += 1
        broadcast.flag_reason = reason

        # Auto-escalate if flagged by 3 or more users
        if broadcast.flag_count >= 3:
            broadcast.status = 'flagged'

        broadcast.save(update_fields=['flag_count', 'flag_reason', 'status'])
        return Response({
            'status': 'Post flagged for moderation.',
            'flag_count': broadcast.flag_count,
            'current_status': broadcast.status
        })

    @action(detail=True, methods=['post'], permission_classes=[IsSystemAdmin])
    def verify(self, request, pk=None):
        """Admin Action: Verify and approve a post (UC 4.1)."""
        broadcast = self.get_object()
        broadcast.status = 'verified'
        broadcast.save(update_fields=['status'])
        return Response({'status': 'Broadcast verified and published to public verified feed.'})

    @action(detail=True, methods=['post'], permission_classes=[IsSystemAdmin])
    def unflag(self, request, pk=None):
        """Admin Action: Dismiss flags and reset to verified."""
        broadcast = self.get_object()
        broadcast.status = 'verified'
        broadcast.flag_count = 0
        broadcast.flag_reason = None
        broadcast.save(update_fields=['status', 'flag_count', 'flag_reason'])
        return Response({'status': 'Flags cleared. Post is clean.'})


# ==========================================
# CHAT MODULE
# ==========================================
class ChatViewSet(viewsets.ModelViewSet):
    queryset = ChatMessage.objects.select_related('sender').all()
    serializer_class = ChatSerializer
    permission_classes = [IsActiveAndUnblocked]
    filter_backends = [filters.OrderingFilter]
    ordering = ['timestamp']
    http_method_names = ['get', 'post', 'head', 'options']

    def perform_create(self, serializer):
        serializer.save(sender=self.request.user)


# ==========================================
# GEOSPATIAL: DISASTER ZONES & SHELTERS
# ==========================================
class DisasterZoneViewSet(viewsets.ModelViewSet):
    queryset = DisasterZone.objects.all()
    serializer_class = DisasterZoneSerializer
    permission_classes = [IsActiveAndUnblocked, IsNGOAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['risk_level', 'is_active', 'disaster_type']
    search_fields = ['name', 'description']


class ShelterViewSet(viewsets.ModelViewSet):
    queryset = Shelter.objects.select_related('managed_by').all()
    serializer_class = ShelterSerializer
    permission_classes = [IsActiveAndUnblocked, IsNGOAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['status']
    search_fields = ['name', 'location_name']


# ==========================================
# AI PREDICTION & SAFE ROUTING APIS
# ==========================================
class DisasterRiskPredictionAPIView(APIView):
    """
    Evaluates real meteorological & crowdsourced data through the PMD model.
    Includes failure detection & heuristic fallback.
    """
    permission_classes = [IsActiveAndUnblocked]

    def post(self, request):
        result = DisasterRiskPredictor.predict(request.data)
        return Response(result)


class SafeRouteAPIView(APIView):
    """
    Calculates disaster-aware evacuation route using Dijkstra / A*.
    Dynamically avoids active disaster zones. Falls back to least-risk path if necessary.
    """
    permission_classes = [IsActiveAndUnblocked]

    def post(self, request):
        start = request.data.get('start')
        destination = request.data.get('destination')
        if not start or not destination:
            return Response({'error': "Both 'start' and 'destination' corridor names are required."}, status=status.HTTP_400_BAD_REQUEST)

        route_info = DisasterAwareRoutingEngine.calculate_safe_route(start, destination)
        status_code = status.HTTP_200_OK if route_info.get('success') else status.HTTP_404_NOT_FOUND
        return Response(route_info, status=status_code)


# ==========================================
# AUDIT LOGS (ADMIN ONLY)
# ==========================================
class AuditLogViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = AuditLog.objects.select_related('actor').all()
    serializer_class = AuditLogSerializer
    permission_classes = [IsSystemAdmin]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['action', 'target_model', 'details']
    ordering = ['-timestamp']
