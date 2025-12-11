"""
Serializers for Todo API.
"""
from rest_framework import serializers


class TodoSerializer(serializers.Serializer):
    """Serializer for Todo items."""
    
    id = serializers.CharField(read_only=True)
    title = serializers.CharField(required=True, max_length=200)
    description = serializers.CharField(required=False, allow_blank=True, default='')
    completed = serializers.BooleanField(required=False, default=False)
    created_at = serializers.CharField(read_only=True)
    updated_at = serializers.CharField(read_only=True)
    
    def validate_title(self, value):
        """Validate that title is not empty."""
        if not value or not value.strip():
            raise serializers.ValidationError("Title cannot be empty.")
        return value.strip()
