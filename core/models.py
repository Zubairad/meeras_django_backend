from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator


class User(AbstractUser):
    ROLE_CHOICES = (
        ('citizen', 'Citizen / Victim'),
        ('helper', 'Volunteer / Helper'),
        ('ngo_admin', 'NGO Admin'),
        ('system_admin', 'System Admin'),
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='citizen')
    phone = models.CharField(max_length=30, blank=True, null=True)
    organization_name = models.CharField(max_length=255, blank=True, null=True)
    is_verified_ngo = models.BooleanField(
        default=False,
        help_text="Designates whether this NGO organization has been verified and approved by a system admin."
    )
    is_blocked = models.BooleanField(
        default=False,
        help_text="Designates whether this user account has been suspended or blocked by an administrator."
    )

    def __str__(self):
        org = f" - {self.organization_name}" if self.organization_name else ""
        return f"{self.username} [{self.get_role_display()}]{org}"


class DisasterZone(models.Model):
    RISK_CHOICES = (
        ('Low', 'Low Risk'),
        ('Medium', 'Medium Risk'),
        ('High', 'High Risk'),
        ('Critical', 'Critical Risk'),
    )

    name = models.CharField(max_length=255)
    disaster_type = models.CharField(max_length=100, default='Flood')
    risk_level = models.CharField(max_length=20, choices=RISK_CHOICES, default='High', db_index=True)
    latitude = models.FloatField(help_text="Center latitude")
    longitude = models.FloatField(help_text="Center longitude")
    radius_km = models.FloatField(default=10.0, help_text="Impact zone radius in kilometers")
    is_active = models.BooleanField(default=True, db_index=True)
    description = models.TextField(blank=True)
    reported_rainfall_mm = models.FloatField(default=0.0)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        status = "Active" if self.is_active else "Resolved"
        return f"{self.name} ({self.disaster_type}) - [{self.risk_level}] ({status})"


class Shelter(models.Model):
    STATUS_CHOICES = (
        ('Open', 'Open / Available'),
        ('Full', 'Full Capacity'),
        ('Closed', 'Closed / Inactive'),
    )

    name = models.CharField(max_length=255)
    location_name = models.CharField(max_length=255)
    latitude = models.FloatField()
    longitude = models.FloatField()
    capacity = models.PositiveIntegerField(default=200)
    current_occupancy = models.PositiveIntegerField(default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Open', db_index=True)
    contact_number = models.CharField(max_length=50, blank=True)
    managed_by = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='managed_shelters', limit_choices_to={'role': 'ngo_admin'}
    )
    created_at = models.DateTimeField(auto_now_add=True)

    @property
    def available_beds(self):
        return max(0, self.capacity - self.current_occupancy)

    def __str__(self):
        return f"{self.name} ({self.location_name}) [{self.status}]"


class HelpRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )

    title = models.CharField(max_length=255)
    description = models.TextField()
    location = models.CharField(max_length=255)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    urgency = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        help_text="Urgency level from 1 (low) to 5 (critical)"
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending', db_index=True)
    assigned_to = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='assigned_requests', limit_choices_to={'role': 'helper'}
    )
    created_by = models.ForeignKey(
        User, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='created_requests'
    )
    people_affected = models.PositiveIntegerField(default=1)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)
    resolved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} [Urgency {self.urgency}] [{self.status}]"


class Inventory(models.Model):
    CATEGORY_CHOICES = (
        ('Food', 'Food & Rations'),
        ('Water', 'Clean Drinking Water'),
        ('Medical', 'First Aid & Medical Kits'),
        ('Shelter', 'Tents, Blankets & Tarps'),
        ('Sanitation', 'Hygiene & Sanitation Kits'),
        ('General', 'General Supplies'),
    )

    ngo = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='inventory_items', limit_choices_to={'role': 'ngo_admin'}
    )
    item_name = models.CharField(max_length=255)
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES, default='General')
    quantity = models.PositiveIntegerField(default=0)
    low_stock_threshold = models.PositiveIntegerField(default=10)
    unit = models.CharField(max_length=50, default='units')

    class Meta:
        verbose_name_plural = 'Inventory'
        unique_together = ('ngo', 'item_name')

    @property
    def is_low_stock(self):
        return self.quantity <= self.low_stock_threshold

    def __str__(self):
        return f"{self.item_name} ({self.quantity} {self.unit}) - {self.ngo.organization_name or self.ngo.username}"


class InventoryLog(models.Model):
    item = models.ForeignKey(Inventory, on_delete=models.CASCADE, related_name='logs')
    change_quantity = models.IntegerField(help_text="Positive for restock, negative for distributed usage")
    balance_after = models.PositiveIntegerField()
    reason = models.CharField(max_length=255)
    logged_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        sign = "+" if self.change_quantity > 0 else ""
        return f"{self.item.item_name}: {sign}{self.change_quantity} ({self.reason})"


class Personnel(models.Model):
    ngo = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='personnel', limit_choices_to={'role': 'ngo_admin'}
    )
    name = models.CharField(max_length=255)
    role = models.CharField(max_length=255, help_text="e.g. Paramedic, Rescue Swimmer, Driver, Coordinator")
    contact_number = models.CharField(max_length=50, blank=True)
    available = models.BooleanField(default=True, db_index=True)
    assigned_request = models.ForeignKey(
        HelpRequest, null=True, blank=True, on_delete=models.SET_NULL,
        related_name='assigned_personnel'
    )

    class Meta:
        verbose_name_plural = 'Personnel'

    def __str__(self):
        status = "Available" if self.available else "Deployed / Unavailable"
        return f"{self.name} — {self.role} ({status})"


class Broadcast(models.Model):
    STATUS_CHOICES = (
        ('verified', 'Verified'),
        ('flagged', 'Flagged'),
        ('pending', 'Pending Review'),
    )

    posted_by = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='broadcasts'
    )
    message = models.TextField()
    location = models.CharField(max_length=255, blank=True, null=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='verified', db_index=True)
    flag_count = models.PositiveIntegerField(default=0)
    flag_reason = models.CharField(max_length=255, blank=True, null=True)
    is_urgent = models.BooleanField(default=False, db_index=True)
    attachment = models.FileField(upload_to='broadcasts/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"[{self.status.upper()}] {self.posted_by.username}: {self.message[:40]}"


class ChatMessage(models.Model):
    sender = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='sent_messages'
    )
    message = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    is_flagged = models.BooleanField(default=False)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"{self.sender.username}: {self.message[:50]}"


class AuditLog(models.Model):
    actor = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True, related_name='audit_actions'
    )
    action = models.CharField(max_length=255)
    target_model = models.CharField(max_length=100, blank=True)
    target_id = models.CharField(max_length=100, blank=True)
    details = models.TextField(blank=True)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        user_str = self.actor.username if self.actor else "System"
        return f"[{self.timestamp:%Y-%m-%d %H:%M}] {user_str} - {self.action} on {self.target_model} #{self.target_id}"
