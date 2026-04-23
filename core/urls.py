from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, HelpRequestViewSet, InventoryViewSet,
    PersonnelViewSet, BroadcastViewSet, ChatViewSet
)

router = DefaultRouter()
router.register(r'users', UserViewSet)
router.register(r'help-requests', HelpRequestViewSet)
router.register(r'inventory', InventoryViewSet)
router.register(r'personnel', PersonnelViewSet)
router.register(r'broadcasts', BroadcastViewSet)
router.register(r'chat', ChatViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
