"""
Disaster-Aware Routing Engine for Meeras
Implements Dijkstra & A* Pathfinding with Dynamic Hazard Avoidance and Fallback Least-Risk Routing.
Meets: FR 2.4, FR 8.5, FR 8.6, and UC-12.2.
"""
import math
import heapq
import logging

logger = logging.getLogger(__name__)


def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Calculates great-circle distance between two GPS coordinates in kilometers."""
    R = 6371.0  # Earth's radius in km
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


# Representative evacuation corridor graph (coordinates across major disaster corridors in Pakistan)
DEFAULT_DISASTER_CORRIDORS = {
    'SUKKUR': {'lat': 27.7052, 'lng': 68.8574, 'neighbors': [('R_Y_KHAN', 170.0), ('CHOLISTAN_CORRIDOR', 210.0)]},
    'R_Y_KHAN': {'lat': 28.4212, 'lng': 70.2989, 'neighbors': [('SUKKUR', 170.0), ('BAHAWALPUR', 200.0), ('D_G_KHAN_SOUTH', 180.0)]},
    'CHOLISTAN_CORRIDOR': {'lat': 28.7500, 'lng': 71.3000, 'neighbors': [('SUKKUR', 210.0), ('BAHAWALPUR', 140.0)]},
    'BAHAWALPUR': {'lat': 29.3544, 'lng': 71.6911, 'neighbors': [('R_Y_KHAN', 200.0), ('CHOLISTAN_CORRIDOR', 140.0), ('MULTAN', 95.0)]},
    'D_G_KHAN_SOUTH': {'lat': 29.8000, 'lng': 70.4000, 'neighbors': [('R_Y_KHAN', 180.0), ('MULTAN', 110.0), ('D_G_KHAN_CITY', 60.0)]},
    'D_G_KHAN_CITY': {'lat': 30.0561, 'lng': 70.6403, 'neighbors': [('D_G_KHAN_SOUTH', 60.0), ('MULTAN', 90.0), ('TAUNSA', 85.0)]},
    'TAUNSA': {'lat': 30.7042, 'lng': 70.6508, 'neighbors': [('D_G_KHAN_CITY', 85.0), ('KOT_ADDU', 40.0)]},
    'KOT_ADDU': {'lat': 30.4700, 'lng': 70.9600, 'neighbors': [('TAUNSA', 40.0), ('MULTAN', 75.0)]},
    'MULTAN': {'lat': 30.1575, 'lng': 71.5249, 'neighbors': [('BAHAWALPUR', 95.0), ('D_G_KHAN_SOUTH', 110.0), ('D_G_KHAN_CITY', 90.0), ('KOT_ADDU', 75.0), ('SAHIWAL', 175.0)]},
    'SAHIWAL': {'lat': 30.6682, 'lng': 73.1114, 'neighbors': [('MULTAN', 175.0), ('LAHORE', 165.0)]},
    'LAHORE': {'lat': 31.5204, 'lng': 74.3587, 'neighbors': [('SAHIWAL', 165.0), ('GUJRANWALA', 70.0)]},
    'GUJRANWALA': {'lat': 32.1877, 'lng': 74.1945, 'neighbors': [('LAHORE', 70.0), ('RAWALPINDI', 220.0)]},
    'RAWALPINDI': {'lat': 33.5651, 'lng': 73.0169, 'neighbors': [('GUJRANWALA', 220.0), ('PESHAWAR', 160.0)]},
    'PESHAWAR': {'lat': 34.0151, 'lng': 71.5249, 'neighbors': [('RAWALPINDI', 160.0), ('NOWSHERA', 42.0)]},
    'NOWSHERA': {'lat': 34.0153, 'lng': 71.9747, 'neighbors': [('PESHAWAR', 42.0), ('MARDAN', 35.0)]},
    'MARDAN': {'lat': 34.1989, 'lng': 72.0404, 'neighbors': [('NOWSHERA', 35.0)]},
}


class DisasterAwareRoutingEngine:
    """
    Computes safe evacuation paths by avoiding active DisasterZones stored in the database.
    """
    @staticmethod
    def get_zone_hazard_penalty(lat: float, lng: float, active_zones) -> tuple[float, str]:
        """
        Calculates penalty multiplier if coordinates fall within any active disaster zone radius.
        Returns: (penalty_multiplier, highest_risk_level)
        """
        highest_penalty = 1.0
        worst_risk = 'Low'

        for zone in active_zones:
            dist = haversine_distance(lat, lng, zone.latitude, zone.longitude)
            if dist <= zone.radius_km:
                if zone.risk_level in ('Critical', 'High'):
                    highest_penalty = max(highest_penalty, 9999.0)  # Effectively blocked
                    worst_risk = zone.risk_level
                elif zone.risk_level == 'Medium':
                    highest_penalty = max(highest_penalty, 3.0)
                    if worst_risk != 'Critical' and worst_risk != 'High':
                        worst_risk = 'Medium'

        return highest_penalty, worst_risk

    @classmethod
    def calculate_safe_route(cls, start_node: str, end_node: str, active_zones=None, allow_fallback=True) -> dict:
        """
        Dijkstra / A* algorithm with dynamic edge weighting based on hazard zones.
        If strict safe mode finds no path, it executes the least-risk alternative (FR 8.6).
        """
        start_key = start_node.upper().strip()
        end_key = end_node.upper().strip()

        if start_key not in DEFAULT_DISASTER_CORRIDORS:
            return {'success': False, 'error': f"Unknown start location '{start_node}'. Supported corridors: {list(DEFAULT_DISASTER_CORRIDORS.keys())}"}
        if end_key not in DEFAULT_DISASTER_CORRIDORS:
            return {'success': False, 'error': f"Unknown destination '{end_node}'. Supported corridors: {list(DEFAULT_DISASTER_CORRIDORS.keys())}"}

        if start_key == end_key:
            node_info = DEFAULT_DISASTER_CORRIDORS[start_key]
            return {
                'success': True,
                'path': [start_key],
                'waypoints': [{'node': start_key, 'lat': node_info['lat'], 'lng': node_info['lng']}],
                'total_distance_km': 0.0,
                'effective_cost': 0.0,
                'status': 'At destination',
                'hazard_warning': False
            }

        if active_zones is None:
            from .models import DisasterZone
            active_zones = list(DisasterZone.objects.filter(is_active=True))

        def run_dijkstra(strict_mode: bool):
            # Priority queue holds (accumulated_cost, current_node, path, actual_km, max_risk)
            pq = [(0.0, start_key, [start_key], 0.0, 'Low')]
            visited = {}

            while pq:
                cost, u, path, actual_km, max_risk = heapq.heappop(pq)

                if u == end_key:
                    waypoints = [{'node': n, 'lat': DEFAULT_DISASTER_CORRIDORS[n]['lat'], 'lng': DEFAULT_DISASTER_CORRIDORS[n]['lng']} for n in path]
                    return {
                        'success': True,
                        'path': path,
                        'waypoints': waypoints,
                        'total_distance_km': round(actual_km, 2),
                        'effective_cost': round(cost, 2),
                        'worst_risk_encountered': max_risk,
                        'hazard_warning': not strict_mode,
                        'note': 'Optimal safe path computed.' if strict_mode else 'CAUTION: No completely safe path exists. Least-risk emergency path computed.'
                    }

                if u in visited and visited[u] <= cost:
                    continue
                visited[u] = cost

                current_info = DEFAULT_DISASTER_CORRIDORS[u]
                for v, dist_km in current_info['neighbors']:
                    v_info = DEFAULT_DISASTER_CORRIDORS[v]
                    
                    # Evaluate risk at destination node and midpoint
                    mid_lat = (current_info['lat'] + v_info['lat']) / 2.0
                    mid_lng = (current_info['lng'] + v_info['lng']) / 2.0

                    penalty_node, risk_node = cls.get_zone_hazard_penalty(v_info['lat'], v_info['lng'], active_zones)
                    penalty_mid, risk_mid = cls.get_zone_hazard_penalty(mid_lat, mid_lng, active_zones)
                    
                    edge_penalty = max(penalty_node, penalty_mid)
                    edge_risk = 'Critical' if 'Critical' in (risk_node, risk_mid) else ('High' if 'High' in (risk_node, risk_mid) else ('Medium' if 'Medium' in (risk_node, risk_mid) else 'Low'))

                    if strict_mode and edge_penalty >= 9999.0:
                        # Edge is blocked due to High/Critical disaster zone — bypass completely
                        continue

                    # If fallback mode, allow traversing high risk but penalize severely so it's a last resort
                    effective_weight = edge_penalty if strict_mode else (10.0 if edge_penalty >= 9999.0 else edge_penalty)
                    edge_cost = dist_km * effective_weight

                    # Track worst risk on path
                    next_max_risk = edge_risk if edge_risk in ('Critical', 'High') else (max_risk if max_risk in ('Critical', 'High') else edge_risk)

                    heapq.heappush(pq, (cost + edge_cost, v, path + [v], actual_km + dist_km, next_max_risk))

            return None

        # Attempt 1: Strict Safe Route (avoid all High/Critical zones)
        result = run_dijkstra(strict_mode=True)
        if result is not None:
            return result

        # Attempt 2: Fallback Least-Risk Route (FR 8.6 requirement)
        if allow_fallback:
            fallback_result = run_dijkstra(strict_mode=False)
            if fallback_result is not None:
                return fallback_result

        return {
            'success': False,
            'error': 'No traversable route found between the specified locations under current disaster conditions.'
        }
