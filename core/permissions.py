from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsNGOAdmin(BasePermission):
    """Allows access only to users with the ngo_admin role."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role == 'ngo_admin')


class IsSystemAdmin(BasePermission):
    """Allows access only to system admins."""
    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and request.user.role == 'system_admin')


class IsNGOAdminOrReadOnly(BasePermission):
    """Read-only for authenticated users; write access for NGO admins only."""
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if request.method in SAFE_METHODS:
            return True
        return request.user.role == 'ngo_admin'


class IsOwnerOrReadOnly(BasePermission):
    """Object-level: only the owner can edit; others can read."""
    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        owner = getattr(obj, 'posted_by', None) or getattr(obj, 'ngo', None) or getattr(obj, 'sender', None)
        return owner == request.user
