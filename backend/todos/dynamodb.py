"""
DynamoDB client and operations for Todo items.
"""

import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

import boto3
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from django.conf import settings

logger = logging.getLogger(__name__)


class DynamoDBClient:
    """Client for interacting with DynamoDB."""

    def __init__(self) -> None:
        """Initialize DynamoDB client with proper configuration."""
        # Configure boto3 with retry logic and timeouts
        boto_config = Config(
            region_name=settings.AWS_REGION,
            retries={
                "max_attempts": 3,
                "mode": "adaptive",
            },
            connect_timeout=5,
            read_timeout=10,
        )

        self.dynamodb = boto3.resource("dynamodb", config=boto_config)
        self.table_name: str = settings.DYNAMODB_TABLE_NAME
        self.table = self.dynamodb.Table(self.table_name)

    def create_todo(self, title: str, description: str = "", completed: bool = False) -> Dict[str, Any]:
        """
        Create a new todo item.

        Args:
            title: The title of the todo item
            description: Optional description
            completed: Whether the todo is completed

        Returns:
            The created todo item as a dictionary

        Raises:
            ClientError: If DynamoDB operation fails
            BotoCoreError: If there's a connection or configuration error
        """
        todo_id = str(uuid.uuid4())
        timestamp = datetime.now(timezone.utc).isoformat()

        item = {
            "id": todo_id,
            "title": title,
            "description": description,
            "completed": completed,
            "created_at": timestamp,
            "updated_at": timestamp,
        }

        try:
            self.table.put_item(Item=item)
            return item
        except (ClientError, BotoCoreError) as e:
            logger.error("Failed to create todo: %s", str(e))
            raise

    def get_todo(self, todo_id: str) -> Optional[Dict[str, Any]]:
        """
        Get a single todo by ID.

        Args:
            todo_id: The ID of the todo item

        Returns:
            The todo item if found, None otherwise

        Raises:
            ClientError: If DynamoDB operation fails
            BotoCoreError: If there's a connection or configuration error
        """
        try:
            response = self.table.get_item(Key={"id": todo_id})
            return response.get("Item")
        except (ClientError, BotoCoreError) as e:
            logger.error("Failed to get todo %s: %s", todo_id, str(e))
            raise

    def list_todos(self) -> List[Dict[str, Any]]:
        """
        List all todos with pagination handling.

        Returns:
            List of todo items sorted by creation date (descending)

        Raises:
            ClientError: If DynamoDB operation fails
            BotoCoreError: If there's a connection or configuration error
        """
        try:
            response = self.table.scan()
            items = response.get("Items", [])

            # Handle pagination if there are more items
            while "LastEvaluatedKey" in response:
                response = self.table.scan(ExclusiveStartKey=response["LastEvaluatedKey"])
                items.extend(response.get("Items", []))

            # Sort by created_at descending
            items.sort(key=lambda x: x.get("created_at", ""), reverse=True)
            return items
        except (ClientError, BotoCoreError) as e:
            logger.error("Failed to list todos: %s", str(e))
            raise

    def update_todo(
        self,
        todo_id: str,
        title: Optional[str] = None,
        description: Optional[str] = None,
        completed: Optional[bool] = None,
    ) -> Optional[Dict[str, Any]]:
        """
        Update a todo item.

        Args:
            todo_id: The ID of the todo item to update
            title: New title (if provided)
            description: New description (if provided)
            completed: New completion status (if provided)

        Returns:
            The updated todo item

        Raises:
            ClientError: If DynamoDB operation fails
            BotoCoreError: If there's a connection or configuration error
        """
        timestamp = datetime.now(timezone.utc).isoformat()

        update_expression = "SET updated_at = :updated_at"
        expression_values: Dict[str, Any] = {":updated_at": timestamp}

        if title is not None:
            update_expression += ", title = :title"
            expression_values[":title"] = title

        if description is not None:
            update_expression += ", description = :description"
            expression_values[":description"] = description

        if completed is not None:
            update_expression += ", completed = :completed"
            expression_values[":completed"] = completed

        try:
            response = self.table.update_item(
                Key={"id": todo_id},
                UpdateExpression=update_expression,
                ExpressionAttributeValues=expression_values,
                ReturnValues="ALL_NEW",
            )
            return response.get("Attributes")
        except (ClientError, BotoCoreError) as e:
            logger.error("Failed to update todo %s: %s", todo_id, str(e))
            raise

    def delete_todo(self, todo_id: str) -> bool:
        """
        Delete a todo item.

        Args:
            todo_id: The ID of the todo item to delete

        Returns:
            True if deletion was successful

        Raises:
            ClientError: If DynamoDB operation fails
            BotoCoreError: If there's a connection or configuration error
        """
        try:
            self.table.delete_item(Key={"id": todo_id})
            return True
        except (ClientError, BotoCoreError) as e:
            logger.error("Failed to delete todo %s: %s", todo_id, str(e))
            raise

    def table_exists(self) -> bool:
        """
        Check if the DynamoDB table exists.

        Returns:
            True if the table exists, False otherwise
        """
        try:
            self.table.load()
            return True
        except ClientError as e:
            # ResourceNotFoundException means table doesn't exist
            if e.response["Error"]["Code"] == "ResourceNotFoundException":
                return False
            # Re-raise other client errors
            raise
        except BotoCoreError:
            # Connection errors mean we can't determine if table exists
            return False


# Singleton instance
_db_client: Optional[DynamoDBClient] = None


def get_db_client() -> DynamoDBClient:
    """
    Get or create the DynamoDB client singleton.

    Returns:
        The singleton DynamoDBClient instance
    """
    global _db_client  # pylint: disable=global-statement
    if _db_client is None:
        _db_client = DynamoDBClient()
    return _db_client
