"""
DynamoDB client and operations for Todo items.
"""
import boto3
from django.conf import settings
import uuid
from datetime import datetime


class DynamoDBClient:
    """Client for interacting with DynamoDB."""
    
    def __init__(self):
        self.dynamodb = boto3.resource('dynamodb', region_name=settings.AWS_REGION)
        self.table_name = settings.DYNAMODB_TABLE_NAME
        self.table = self.dynamodb.Table(self.table_name)
    
    def create_todo(self, title, description='', completed=False):
        """Create a new todo item."""
        todo_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'id': todo_id,
            'title': title,
            'description': description,
            'completed': completed,
            'created_at': timestamp,
            'updated_at': timestamp
        }
        
        self.table.put_item(Item=item)
        return item
    
    def get_todo(self, todo_id):
        """Get a single todo by ID."""
        response = self.table.get_item(Key={'id': todo_id})
        return response.get('Item')
    
    def list_todos(self):
        """List all todos."""
        response = self.table.scan()
        items = response.get('Items', [])
        
        # Handle pagination if there are more items
        while 'LastEvaluatedKey' in response:
            response = self.table.scan(ExclusiveStartKey=response['LastEvaluatedKey'])
            items.extend(response.get('Items', []))
        
        # Sort by created_at descending
        items.sort(key=lambda x: x.get('created_at', ''), reverse=True)
        return items
    
    def update_todo(self, todo_id, title=None, description=None, completed=None):
        """Update a todo item."""
        timestamp = datetime.utcnow().isoformat()
        
        update_expression = "SET updated_at = :updated_at"
        expression_values = {':updated_at': timestamp}
        
        if title is not None:
            update_expression += ", title = :title"
            expression_values[':title'] = title
        
        if description is not None:
            update_expression += ", description = :description"
            expression_values[':description'] = description
        
        if completed is not None:
            update_expression += ", completed = :completed"
            expression_values[':completed'] = completed
        
        response = self.table.update_item(
            Key={'id': todo_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ReturnValues='ALL_NEW'
        )
        
        return response.get('Attributes')
    
    def delete_todo(self, todo_id):
        """Delete a todo item."""
        self.table.delete_item(Key={'id': todo_id})
        return True
    
    def table_exists(self):
        """Check if the DynamoDB table exists."""
        try:
            self.table.load()
            return True
        except Exception:
            return False


# Singleton instance
_db_client = None

def get_db_client():
    """Get or create the DynamoDB client singleton."""
    global _db_client
    if _db_client is None:
        _db_client = DynamoDBClient()
    return _db_client
