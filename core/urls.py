from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, HelpRequestViewSet, InventoryViewSet,
    PersonnelViewSet, BroadcastViewSet, ChatViewSet,
    DisasterZoneViewSet, ShelterViewSet, AuditLogViewSet,
    DisasterRiskPredictionAPIView, SafeRouteAPIView
)

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'help-requests', HelpRequestViewSet)
router.register(r'inventory', InventoryViewSet)
router.register(r'personnel', PersonnelViewSet)
router.register(r'broadcasts', BroadcastViewSet)
router.register(r'chat', ChatViewSet)
router.register(r'disaster-zones', DisasterZoneViewSet)
router.register(r'shelters', ShelterViewSet)
router.register(r'audit-logs', AuditLogViewSet)

urlpatterns = [
    path('predict-risk/', DisasterRiskPredictionAPIView.as_view(), name='predict_risk'),
    path('routes/safe-route/', SafeRouteAPIView.as_view(), name='safe_route'),
    path('', include(router.urls)),
]
