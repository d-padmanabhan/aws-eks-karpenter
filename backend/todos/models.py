"""
Django models for the todos application.

Note: This application uses Amazon DynamoDB as its primary data store instead of
Django's ORM and traditional relational databases. Therefore, this file contains
conceptual model definitions for documentation purposes only.

The actual data operations are handled by the DynamoDB client in dynamodb.py.

Database Schema (DynamoDB):
==========================

Table Name: todo-app-table (configurable via DYNAMODB_TABLE_NAME)
Partition Key: id (String)

Attributes:
-----------
- id (String): Unique identifier (UUID4)
- title (String): Todo item title (required, max 200 characters)
- description (String): Todo item description (optional)
- completed (Boolean): Completion status (default: False)
- created_at (String): ISO 8601 timestamp of creation
- updated_at (String): ISO 8601 timestamp of last update

Indexes:
--------
No secondary indexes are currently defined. All queries use the primary key (id).

Example Item:
-------------
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Complete project documentation",
    "description": "Write comprehensive README and API docs",
    "completed": false,
    "created_at": "2024-01-15T10:30:00.000000",
    "updated_at": "2024-01-15T10:30:00.000000"
}

Access Patterns:
---------------
1. Get single todo by ID: GetItem with id
2. List all todos: Scan operation (sorted by created_at desc)
3. Create todo: PutItem with generated UUID
4. Update todo: UpdateItem with id
5. Delete todo: DeleteItem with id

Security:
---------
Access to DynamoDB is controlled via IAM Roles for Service Accounts (IRSA).
The backend pods assume an IAM role that grants specific DynamoDB permissions:
- dynamodb:GetItem
- dynamodb:PutItem
- dynamodb:UpdateItem
- dynamodb:DeleteItem
- dynamodb:Scan
- dynamodb:Query
- dynamodb:DescribeTable

For more details on the DynamoDB implementation, see:
- dynamodb.py: DynamoDB client and operations
- views.py: API endpoints that use the DynamoDB client
- serializers.py: Data validation and serialization
"""

# Django models are not used in this application as we're using DynamoDB.
# If you need to use Django's admin interface or other ORM features,
# you would define models here. However, for this application, all data
# operations are performed directly through the DynamoDB client.

# Example of how a Django model would look if we were using Django ORM:
#
# from django.db import models
# import uuid
#
# class Todo(models.Model):
#     '''
#     Todo model - NOT USED (DynamoDB is used instead)
#     This is kept for reference only.
#     '''
#     id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
#     title = models.CharField(max_length=200)
#     description = models.TextField(blank=True, default='')
#     completed = models.BooleanField(default=False)
#     created_at = models.DateTimeField(auto_now_add=True)
#     updated_at = models.DateTimeField(auto_now=True)
#
#     class Meta:
#         ordering = ['-created_at']
#         verbose_name = 'Todo'
#         verbose_name_plural = 'Todos'
#
#     def __str__(self):
#         return self.title
