from rest_framework import serializers
from .models import (
    User, HelpRequest, Inventory, InventoryLog, Personnel,
    Broadcast, ChatMessage, DisasterZone, Shelter, AuditLog
)


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            'id', 'username', 'email', 'first_name', 'last_name',
            'role', 'phone', 'organization_name', 'is_verified_ngo', 'is_blocked'
        )
        read_only_fields = ('id', 'is_verified_ngo', 'is_blocked')


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'first_name', 'last_name', 'role', 'phone', 'organization_name')

    def validate_role(self, value):
        # Security: Prevent unauthorized registration as system_admin
        if value == 'system_admin':
            raise serializers.ValidationError("Cannot register as System Administrator directly. Contact an administrator.")
        return value

    def create(self, validated_data):
        role = validated_data.get('role', 'citizen')
        # If registering as an NGO Admin, require admin verification before activation
        user = User.objects.create_user(**validated_data)
        if role == 'ngo_admin':
            user.is_verified_ngo = False
            user.save(update_fields=['is_verified_ngo'])

        AuditLog.objects.create(
            actor=user,
            action='USER_REGISTERED',
            target_model='User',
            target_id=str(user.id),
            details=f"Registered with role {user.role}"
        )
        return user


class DisasterZoneSerializer(serializers.ModelSerializer):
    class Meta:
        model = DisasterZone
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'updated_at')


class ShelterSerializer(serializers.ModelSerializer):
    available_beds = serializers.IntegerField(read_only=True)
    managed_by_name = serializers.CharField(source='managed_by.username', read_only=True)

    class Meta:
        model = Shelter
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'available_beds')


class HelpRequestSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.CharField(source='assigned_to.get_full_name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    is_urgent = serializers.SerializerMethodField()

    class Meta:
        model = HelpRequest
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'updated_at', 'created_by', 'resolved_at', 'assigned_to')

    def get_is_urgent(self, obj):
        return obj.urgency >= 4


class InventoryLogSerializer(serializers.ModelSerializer):
    logged_by_name = serializers.CharField(source='logged_by.username', read_only=True)

    class Meta:
        model = InventoryLog
        fields = '__all__'
        read_only_fields = ('id', 'timestamp')


class InventorySerializer(serializers.ModelSerializer):
    is_low_stock = serializers.BooleanField(read_only=True)
    ngo_name = serializers.CharField(source='ngo.organization_name', read_only=True)
    logs = InventoryLogSerializer(many=True, read_only=True)

    class Meta:
        model = Inventory
        fields = '__all__'
        read_only_fields = ('id', 'ngo', 'is_low_stock')


class PersonnelSerializer(serializers.ModelSerializer):
    ngo_name = serializers.CharField(source='ngo.organization_name', read_only=True)
    assigned_request_title = serializers.CharField(source='assigned_request.title', read_only=True)

    class Meta:
        model = Personnel
        fields = '__all__'
        read_only_fields = ('id', 'ngo')


class BroadcastSerializer(serializers.ModelSerializer):
    posted_by_username = serializers.CharField(source='posted_by.username', read_only=True)

    class Meta:
        model = Broadcast
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'posted_by', 'flag_count', 'status')


class ChatSerializer(serializers.ModelSerializer):
    sender_username = serializers.CharField(source='sender.username', read_only=True)

    class Meta:
        model = ChatMessage
        fields = '__all__'
        read_only_fields = ('id', 'timestamp', 'sender')


class AuditLogSerializer(serializers.ModelSerializer):
    actor_username = serializers.CharField(source='actor.username', read_only=True)

    class Meta:
        model = AuditLog
        fields = '__all__'
        read_only_fields = ('id', 'timestamp')
