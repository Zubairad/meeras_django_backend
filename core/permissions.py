from rest_framework.permissions import BasePermission, SAFE_METHODS


def is_active_unblocked(user) -> bool:
    return bool(user and user.is_authenticated and not getattr(user, 'is_blocked', False))


class IsActiveAndUnblocked(BasePermission):
    """Denies access if user is anonymous or has been blocked by an administrator."""
    def has_permission(self, request, view):
        return is_active_unblocked(request.user)


class IsSystemAdmin(BasePermission):
    """Allows access only to system administrators or superusers."""
    def has_permission(self, request, view):
        if not is_active_unblocked(request.user):
            return False
        return request.user.role == 'system_admin' or request.user.is_superuser


class IsNGOAdmin(BasePermission):
    """Allows access only to verified NGO administrators."""
    def has_permission(self, request, view):
        if not is_active_unblocked(request.user):
            return False
        if request.user.is_superuser or request.user.role == 'system_admin':
            return True
        return request.user.role == 'ngo_admin' and getattr(request.user, 'is_verified_ngo', False)


class IsNGOAdminOrReadOnly(BasePermission):
    """Read-only for authenticated users; write access for verified NGO admins or system admin."""
    def has_permission(self, request, view):
        if not is_active_unblocked(request.user):
            return False
        if request.method in SAFE_METHODS:
            return True
        if request.user.is_superuser or request.user.role == 'system_admin':
            return True
        return request.user.role == 'ngo_admin' and getattr(request.user, 'is_verified_ngo', False)


class IsOwnerOrAdminOrReadOnly(BasePermission):
    """
    Object-level permission:
    - SAFE_METHODS allowed for any authenticated user.
    - Write actions allowed only for the resource creator/owner or system admin.
    """
    def has_permission(self, request, view):
        return is_active_unblocked(request.user)

    def has_object_permission(self, request, view, obj):
        if request.method in SAFE_METHODS:
            return True
        user = request.user
        if user.is_superuser or getattr(user, 'role', '') == 'system_admin':
            return True

        # Check standard owner attributes
        for attr in ('posted_by', 'created_by', 'sender', 'ngo', 'managed_by'):
            owner = getattr(obj, attr, None)
            if owner is not None:
                return owner == user
        return False
