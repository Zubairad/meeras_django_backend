from rest_framework import viewsets, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated, AllowAny
from django_filters.rest_framework import DjangoFilterBackend

from .models import HelpRequest, Inventory, Personnel, Broadcast, ChatMessage, User
from .serializers import (
    HelpRequestSerializer, InventorySerializer, PersonnelSerializer,
    BroadcastSerializer, ChatSerializer, UserSerializer, UserRegistrationSerializer
)
from .permissions import IsNGOAdmin, IsNGOAdminOrReadOnly, IsOwnerOrReadOnly


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ['username', 'email', 'role']

    def get_serializer_class(self):
        if self.action == 'create':
            return UserRegistrationSerializer
        return UserSerializer

    def get_permissions(self):
        if self.action == 'create':
            return [AllowAny()]
        return super().get_permissions()

    @action(detail=False, methods=['get'], permission_classes=[IsAuthenticated])
    def me(self, request):
        """Return the authenticated user's profile."""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)


class HelpRequestViewSet(viewsets.ModelViewSet):
    queryset = HelpRequest.objects.select_related('assigned_to', 'created_by').all()
    serializer_class = HelpRequestSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['status', 'urgency', 'assigned_to']
    search_fields = ['title', 'description', 'location']
    ordering_fields = ['created_at', 'urgency']
    ordering = ['-created_at']

    @action(detail=True, methods=['patch'], permission_classes=[IsAuthenticated, IsNGOAdmin])
    def assign(self, request, pk=None):
        """Assign a helper to a help request."""
        help_request = self.get_object()
        helper_id = request.data.get('assigned_to')
        if not helper_id:
            return Response({'error': 'assigned_to is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            helper = User.objects.get(pk=helper_id, role='helper')
        except User.DoesNotExist:
            return Response({'error': 'Helper not found.'}, status=status.HTTP_404_NOT_FOUND)
        help_request.assigned_to = helper
        help_request.status = 'assigned'
        help_request.save()
        return Response(HelpRequestSerializer(help_request, context={'request': request}).data)

    @action(detail=True, methods=['patch'])
    def complete(self, request, pk=None):
        """Mark a help request as completed."""
        help_request = self.get_object()
        if help_request.status != 'assigned':
            return Response({'error': 'Only assigned requests can be completed.'}, status=status.HTTP_400_BAD_REQUEST)
        help_request.status = 'completed'
        help_request.save()
        return Response(HelpRequestSerializer(help_request, context={'request': request}).data)


class InventoryViewSet(viewsets.ModelViewSet):
    queryset = Inventory.objects.select_related('ngo').all()
    serializer_class = InventorySerializer
    permission_classes = [IsAuthenticated, IsNGOAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['ngo']
    search_fields = ['item_name']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'ngo_admin':
            return Inventory.objects.filter(ngo=user)
        return Inventory.objects.all()

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        """Return items that are at or below their low_stock_threshold."""
        qs = self.get_queryset()
        low = [item for item in qs if item.is_low_stock]
        serializer = self.get_serializer(low, many=True)
        return Response(serializer.data)


class PersonnelViewSet(viewsets.ModelViewSet):
    queryset = Personnel.objects.select_related('ngo').all()
    serializer_class = PersonnelSerializer
    permission_classes = [IsAuthenticated, IsNGOAdminOrReadOnly]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter]
    filterset_fields = ['available', 'ngo']
    search_fields = ['name', 'role']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'ngo_admin':
            return Personnel.objects.filter(ngo=user)
        return Personnel.objects.all()


class BroadcastViewSet(viewsets.ModelViewSet):
    queryset = Broadcast.objects.select_related('posted_by').all()
    serializer_class = BroadcastSerializer
    permission_classes = [IsAuthenticated, IsOwnerOrReadOnly]
    filter_backends = [filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['message', 'location']
    ordering = ['-created_at']

    def get_permissions(self):
        if self.action in ('update', 'partial_update', 'destroy'):
            return [IsAuthenticated(), IsOwnerOrReadOnly()]
        return [IsAuthenticated()]


class ChatViewSet(viewsets.ModelViewSet):
    queryset = ChatMessage.objects.select_related('sender').all()
    serializer_class = ChatSerializer
    permission_classes = [IsAuthenticated]
    filter_backends = [filters.OrderingFilter]
    ordering = ['timestamp']
    http_method_names = ['get', 'post', 'head', 'options']  # No editing/deleting messages
