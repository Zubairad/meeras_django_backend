from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from .models import (
    User, HelpRequest, Inventory, InventoryLog, Personnel,
    Broadcast, ChatMessage, DisasterZone, Shelter, AuditLog
)

# Customize Admin Portal Branding as per Meeras Project Document
admin.site.site_header = "Meeras (مِیراث) — Disaster Management Administration"
admin.site.site_title = "Meeras Admin Portal"
admin.site.index_title = "Emergency Coordination & Disaster Command Dashboard"


@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = (
        'username', 'email', 'get_role_badge', 'organization_name',
        'get_ngo_status', 'get_blocked_status', 'date_joined'
    )
    list_filter = ('role', 'is_verified_ngo', 'is_blocked', 'is_staff')
    search_fields = ('username', 'email', 'organization_name', 'phone')
    ordering = ('-date_joined',)
    actions = ['approve_ngos', 'block_users', 'unblock_users']

    fieldsets = (
        ('Authentication Credentials', {'fields': ('username', 'password')}),
        ('Personal & Contact Info', {'fields': ('first_name', 'last_name', 'email', 'phone')}),
        ('Role & Organization', {'fields': ('role', 'organization_name', 'is_verified_ngo')}),
        ('Security & Moderation', {'fields': ('is_blocked', 'is_active', 'is_staff', 'is_superuser')}),
        ('Important Timestamps', {'fields': ('last_login', 'date_joined')}),
    )

    @admin.display(description='Role')
    def get_role_badge(self, obj):
        colors = {
            'system_admin': '#d32f2f',  # Red
            'ngo_admin': '#1976d2',     # Blue
            'helper': '#388e3c',        # Green
            'citizen': '#7b1fa2'        # Purple
        }
        color = colors.get(obj.role, '#555555')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px;">{}</span>',
            color, obj.get_role_display()
        )

    @admin.display(description='NGO Verification')
    def get_ngo_status(self, obj):
        if obj.role != 'ngo_admin':
            return "—"
        if obj.is_verified_ngo:
            return format_html('<span style="color: #2e7d32; font-weight: bold;">✔ Verified</span>')
        return format_html('<span style="color: #d32f2f; font-weight: bold;">⏳ Pending Approval</span>')

    @admin.display(description='Account Status')
    def get_blocked_status(self, obj):
        if obj.is_blocked:
            return format_html('<span style="background-color: #ffebee; color: #c62828; padding: 2px 6px; border-radius: 3px; font-weight: bold;">BLOCKED</span>')
        return format_html('<span style="color: #2e7d32;">Active</span>')

    @admin.action(description="✔ Approve selected NGO organizations (FR 1.3 / FR 10.2)")
    def approve_ngos(self, request, queryset):
        updated = queryset.filter(role='ngo_admin').update(is_verified_ngo=True)
        self.message_user(request, f"Successfully approved {updated} NGO account(s).")

    @admin.action(description="⛔ Block selected user accounts (FR 10.5 / UC 10.4)")
    def block_users(self, request, queryset):
        updated = queryset.exclude(is_superuser=True).update(is_blocked=True)
        self.message_user(request, f"Successfully blocked {updated} user account(s).")

    @admin.action(description="🔓 Unblock selected user accounts")
    def unblock_users(self, request, queryset):
        updated = queryset.update(is_blocked=False)
        self.message_user(request, f"Successfully restored {updated} user account(s).")


@admin.register(HelpRequest)
class HelpRequestAdmin(admin.ModelAdmin):
    list_display = (
        'title', 'location', 'get_urgency_badge', 'get_status_badge',
        'assigned_to', 'people_affected', 'created_at'
    )
    list_filter = ('status', 'urgency', 'created_at')
    search_fields = ('title', 'description', 'location')
    readonly_fields = ('created_at', 'updated_at', 'resolved_at')
    ordering = ('-created_at',)
    actions = ['mark_as_completed', 'set_critical_urgency']

    @admin.display(description='Urgency')
    def get_urgency_badge(self, obj):
        color = '#388e3c' if obj.urgency <= 2 else ('#f57c00' if obj.urgency == 3 else '#d32f2f')
        label = "Critical" if obj.urgency == 5 else ("High" if obj.urgency == 4 else ("Medium" if obj.urgency == 3 else "Low"))
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px;">Level {} ({})</span>',
            color, obj.urgency, label
        )

    @admin.display(description='Status')
    def get_status_badge(self, obj):
        bg = {'pending': '#fff3e0', 'assigned': '#e3f2fd', 'completed': '#e8f5e9', 'cancelled': '#efebe9'}.get(obj.status, '#eee')
        fg = {'pending': '#e65100', 'assigned': '#1565c0', 'completed': '#2e7d32', 'cancelled': '#4e342e'}.get(obj.status, '#333')
        return format_html(
            '<span style="background-color: {}; color: {}; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px; text-transform: uppercase;">{}</span>',
            bg, fg, obj.status
        )

    @admin.action(description="✔ Mark selected requests as Completed / Resolved")
    def mark_as_completed(self, request, queryset):
        updated = queryset.update(status='completed', resolved_at=timezone.now())
        self.message_user(request, f"{updated} request(s) marked as Completed.")

    @admin.action(description="🚨 Escalate selected requests to Level 5 (Critical)")
    def set_critical_urgency(self, request, queryset):
        updated = queryset.update(urgency=5)
        self.message_user(request, f"{updated} request(s) escalated to Level 5.")


@admin.register(DisasterZone)
class DisasterZoneAdmin(admin.ModelAdmin):
    list_display = ('name', 'disaster_type', 'get_risk_badge', 'latitude', 'longitude', 'radius_km', 'is_active', 'created_at')
    list_filter = ('risk_level', 'disaster_type', 'is_active')
    search_fields = ('name', 'description')
    actions = ['activate_zones', 'deactivate_zones']

    @admin.display(description='Risk Level')
    def get_risk_badge(self, obj):
        colors = {'Low': '#388e3c', 'Medium': '#f57c00', 'High': '#d32f2f', 'Critical': '#880e4f'}
        color = colors.get(obj.risk_level, '#555555')
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 8px; border-radius: 4px; font-weight: bold; font-size: 11px;">{}</span>',
            color, obj.risk_level
        )

    @admin.action(description="🚨 Activate selected disaster zones")
    def activate_zones(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, "Selected disaster zones set to ACTIVE.")

    @admin.action(description="✅ Deactivate selected disaster zones (All Clear)")
    def deactivate_zones(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, "Selected disaster zones deactivated.")


@admin.register(Shelter)
class ShelterAdmin(admin.ModelAdmin):
    list_display = ('name', 'location_name', 'get_capacity_bar', 'status', 'managed_by', 'contact_number')
    list_filter = ('status',)
    search_fields = ('name', 'location_name', 'contact_number')

    @admin.display(description='Occupancy / Capacity')
    def get_capacity_bar(self, obj):
        pct = min(100, int((obj.current_occupancy / max(1, obj.capacity)) * 100))
        color = '#2e7d32' if pct < 70 else ('#f57c00' if pct < 90 else '#d32f2f')
        return format_html(
            '<div style="width: 120px; background-color: #ddd; border-radius: 4px; overflow: hidden; display: inline-block; vertical-align: middle; margin-right: 6px;">'
            '<div style="width: {}%; background-color: {}; height: 12px;"></div>'
            '</div> {}/{} ({}%)',
            pct, color, obj.current_occupancy, obj.capacity, pct
        )


class InventoryLogInline(admin.TabularInline):
    model = InventoryLog
    extra = 0
    readonly_fields = ('change_quantity', 'balance_after', 'reason', 'logged_by', 'timestamp')
    can_delete = False


@admin.register(Inventory)
class InventoryAdmin(admin.ModelAdmin):
    list_display = ('item_name', 'category', 'get_stock_badge', 'low_stock_threshold', 'unit', 'ngo')
    list_filter = ('category', 'ngo')
    search_fields = ('item_name', 'category')
    inlines = [InventoryLogInline]

    @admin.display(description='Current Stock')
    def get_stock_badge(self, obj):
        if obj.is_low_stock:
            return format_html(
                '<span style="background-color: #ffebee; color: #c62828; padding: 3px 8px; border-radius: 4px; font-weight: bold; border: 1px solid #ef9a9a;">⚠ LOW: {} {}</span>',
                obj.quantity, obj.unit
            )
        return format_html(
            '<span style="color: #2e7d32; font-weight: bold;">{} {}</span>',
            obj.quantity, obj.unit
        )


@admin.register(Personnel)
class PersonnelAdmin(admin.ModelAdmin):
    list_display = ('name', 'role', 'get_availability_badge', 'assigned_request', 'contact_number', 'ngo')
    list_filter = ('available', 'ngo')
    search_fields = ('name', 'role', 'contact_number')

    @admin.display(description='Availability')
    def get_availability_badge(self, obj):
        if obj.available:
            return format_html('<span style="color: #2e7d32; font-weight: bold;">✔ Available</span>')
        return format_html('<span style="color: #d32f2f; font-weight: bold;">⛔ Deployed / Busy</span>')


@admin.register(Broadcast)
class BroadcastAdmin(admin.ModelAdmin):
    list_display = ('posted_by', 'get_snippet', 'location', 'get_status_badge', 'flag_count', 'is_urgent', 'created_at')
    list_filter = ('status', 'is_urgent', 'created_at')
    search_fields = ('message', 'location', 'flag_reason')
    actions = ['verify_broadcasts', 'flag_as_misinformation']

    @admin.display(description='Message')
    def get_snippet(self, obj):
        return obj.message[:60] + "..." if len(obj.message) > 60 else obj.message

    @admin.display(description='Status')
    def get_status_badge(self, obj):
        colors = {'verified': '#2e7d32', 'flagged': '#c62828', 'pending': '#f57c00'}
        color = colors.get(obj.status, '#555555')
        return format_html(
            '<span style="color: {}; font-weight: bold; text-transform: uppercase;">● {}</span>',
            color, obj.status
        )

    @admin.action(description="✔ Verify selected broadcasts (publish to verified feed)")
    def verify_broadcasts(self, request, queryset):
        updated = queryset.update(status='verified')
        self.message_user(request, f"{updated} broadcast(s) verified.")

    @admin.action(description="🚩 Flag selected broadcasts as Misinformation / Review Queue")
    def flag_as_misinformation(self, request, queryset):
        updated = queryset.update(status='flagged')
        self.message_user(request, f"{updated} broadcast(s) flagged.")


@admin.register(ChatMessage)
class ChatMessageAdmin(admin.ModelAdmin):
    list_display = ('sender', 'message', 'is_flagged', 'timestamp')
    list_filter = ('is_flagged', 'timestamp')
    search_fields = ('message', 'sender__username')
    readonly_fields = ('sender', 'message', 'timestamp')


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ('timestamp', 'actor', 'action', 'target_model', 'target_id', 'details')
    list_filter = ('action', 'target_model', 'timestamp')
    search_fields = ('action', 'target_model', 'target_id', 'details', 'actor__username')
    readonly_fields = ('actor', 'action', 'target_model', 'target_id', 'details', 'timestamp')

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
