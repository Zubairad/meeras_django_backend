from django.db import models
from django.contrib.auth.models import AbstractUser
from django.core.validators import MinValueValidator, MaxValueValidator


class User(AbstractUser):
    ROLE_CHOICES = (
        ('ngo_admin', 'NGO Admin'),
        ('helper', 'Helper'),
        ('system_admin', 'System Admin'),
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='helper')

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"


class HelpRequest(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('assigned', 'Assigned'),
        ('completed', 'Completed'),
    )

    title = models.CharField(max_length=255)
    description = models.TextField()
    location = models.CharField(max_length=255)
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
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.title} [{self.status}]"


class Inventory(models.Model):
    ngo = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='inventory_items', limit_choices_to={'role': 'ngo_admin'}
    )
    item_name = models.CharField(max_length=255)
    quantity = models.IntegerField(validators=[MinValueValidator(0)])
    low_stock_threshold = models.IntegerField(default=10, validators=[MinValueValidator(0)])

    class Meta:
        verbose_name_plural = 'Inventory'
        unique_together = ('ngo', 'item_name')

    @property
    def is_low_stock(self):
        return self.quantity <= self.low_stock_threshold

    def __str__(self):
        return f"{self.item_name} (qty: {self.quantity})"


class Personnel(models.Model):
    ngo = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='personnel', limit_choices_to={'role': 'ngo_admin'}
    )
    name = models.CharField(max_length=255)
    role = models.CharField(max_length=255)
    available = models.BooleanField(default=True, db_index=True)

    class Meta:
        verbose_name_plural = 'Personnel'

    def __str__(self):
        status = "Available" if self.available else "Unavailable"
        return f"{self.name} — {self.role} ({status})"


class Broadcast(models.Model):
    posted_by = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='broadcasts'
    )
    message = models.TextField()
    location = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Broadcast by {self.posted_by} at {self.created_at:%Y-%m-%d %H:%M}"


class ChatMessage(models.Model):
    sender = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='sent_messages'
    )
    message = models.TextField()
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['timestamp']

    def __str__(self):
        return f"{self.sender.username}: {self.message[:50]}"
