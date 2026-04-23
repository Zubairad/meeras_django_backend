from rest_framework import serializers
from .models import User, HelpRequest, Inventory, Personnel, Broadcast, ChatMessage


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        # Exclude sensitive fields from API responses
        fields = ('id', 'username', 'email', 'first_name', 'last_name', 'role')
        read_only_fields = ('id',)


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'first_name', 'last_name', 'role')

    def create(self, validated_data):
        return User.objects.create_user(**validated_data)


class HelpRequestSerializer(serializers.ModelSerializer):
    assigned_to_name = serializers.CharField(source='assigned_to.get_full_name', read_only=True)
    created_by_name = serializers.CharField(source='created_by.username', read_only=True)
    is_urgent = serializers.SerializerMethodField()

    class Meta:
        model = HelpRequest
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'updated_at', 'created_by')

    def get_is_urgent(self, obj):
        return obj.urgency >= 4

    def validate_urgency(self, value):
        if not (1 <= value <= 5):
            raise serializers.ValidationError("Urgency must be between 1 and 5.")
        return value

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)


class InventorySerializer(serializers.ModelSerializer):
    is_low_stock = serializers.BooleanField(read_only=True)

    class Meta:
        model = Inventory
        fields = '__all__'
        read_only_fields = ('id',)

    def validate_quantity(self, value):
        if value < 0:
            raise serializers.ValidationError("Quantity cannot be negative.")
        return value


class PersonnelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Personnel
        fields = '__all__'
        read_only_fields = ('id',)


class BroadcastSerializer(serializers.ModelSerializer):
    posted_by_username = serializers.CharField(source='posted_by.username', read_only=True)

    class Meta:
        model = Broadcast
        fields = '__all__'
        read_only_fields = ('id', 'created_at', 'posted_by')

    def create(self, validated_data):
        validated_data['posted_by'] = self.context['request'].user
        return super().create(validated_data)


class ChatSerializer(serializers.ModelSerializer):
    sender_username = serializers.CharField(source='sender.username', read_only=True)

    class Meta:
        model = ChatMessage
        fields = '__all__'
        read_only_fields = ('id', 'timestamp', 'sender')

    def create(self, validated_data):
        validated_data['sender'] = self.context['request'].user
        return super().create(validated_data)
