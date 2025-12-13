"""
API views for Todo operations.
"""

# pylint: disable=import-error  # rest_framework not in pylint path
# pylint: disable=too-many-return-statements  # REST API views naturally have many returns
# pylint: disable=too-many-branches  # REST API views naturally have many branches

import logging
from typing import Any, Dict

from botocore.exceptions import BotoCoreError, ClientError
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.request import Request
from rest_framework.response import Response

from .dynamodb import get_db_client
from .serializers import TodoSerializer

logger = logging.getLogger(__name__)


@api_view(["GET", "POST"])
def todo_list(request: Request) -> Response:
    """
    List all todos or create a new todo.

    GET: Returns a list of all todos
    POST: Creates a new todo item

    Args:
        request: The HTTP request object

    Returns:
        Response with todo data or error message
    """
    db = get_db_client()

    if request.method == "GET":
        try:
            todos = db.list_todos()
            serializer = TodoSerializer(todos, many=True)
            return Response(serializer.data)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            logger.error("DynamoDB error listing todos [%s]: %s", error_code, str(e))
            return Response(
                {"error": "Failed to retrieve todos from database"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except BotoCoreError as e:
            logger.error("AWS connection error listing todos: %s", str(e))
            return Response(
                {"error": "Database connection error"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception as e:  # pylint: disable=broad-exception-caught
            logger.exception("Unexpected error listing todos: %s", str(e))
            return Response(
                {"error": "An unexpected error occurred"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    elif request.method == "POST":
        serializer = TodoSerializer(data=request.data)
        if serializer.is_valid():
            try:
                todo = db.create_todo(
                    title=serializer.validated_data["title"],
                    description=serializer.validated_data.get("description", ""),
                    completed=serializer.validated_data.get("completed", False),
                )
                return Response(TodoSerializer(todo).data, status=status.HTTP_201_CREATED)
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code", "Unknown")
                logger.error("DynamoDB error creating todo [%s]: %s", error_code, str(e))
                return Response(
                    {"error": "Failed to create todo in database"},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            except BotoCoreError as e:
                logger.error("AWS connection error creating todo: %s", str(e))
                return Response(
                    {"error": "Database connection error"},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            except Exception as e:  # pylint: disable=broad-exception-caught
                logger.exception("Unexpected error creating todo: %s", str(e))
                return Response(
                    {"error": "An unexpected error occurred"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET", "PUT", "DELETE"])
def todo_detail(request: Request, pk: str) -> Response:
    """
    Retrieve, update or delete a todo.

    GET: Returns a single todo by ID
    PUT: Updates an existing todo
    DELETE: Deletes a todo

    Args:
        request: The HTTP request object
        pk: The primary key (ID) of the todo item

    Returns:
        Response with todo data or error message
    """
    db = get_db_client()

    if request.method == "GET":
        try:
            todo = db.get_todo(pk)
            if not todo:
                return Response({"error": "Todo not found"}, status=status.HTTP_404_NOT_FOUND)
            serializer = TodoSerializer(todo)
            return Response(serializer.data)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            logger.error("DynamoDB error retrieving todo %s [%s]: %s", pk, error_code, str(e))
            return Response(
                {"error": "Failed to retrieve todo from database"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except BotoCoreError as e:
            logger.error("AWS connection error retrieving todo %s: %s", pk, str(e))
            return Response(
                {"error": "Database connection error"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception as e:  # pylint: disable=broad-exception-caught
            logger.exception("Unexpected error retrieving todo %s: %s", pk, str(e))
            return Response(
                {"error": "An unexpected error occurred"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    elif request.method == "PUT":
        serializer = TodoSerializer(data=request.data)
        if serializer.is_valid():
            try:
                # Check if todo exists
                existing = db.get_todo(pk)
                if not existing:
                    return Response({"error": "Todo not found"}, status=status.HTTP_404_NOT_FOUND)

                # Update the todo
                updated_todo = db.update_todo(
                    pk,
                    title=serializer.validated_data.get("title"),
                    description=serializer.validated_data.get("description"),
                    completed=serializer.validated_data.get("completed"),
                )
                return Response(TodoSerializer(updated_todo).data)
            except ClientError as e:
                error_code = e.response.get("Error", {}).get("Code", "Unknown")
                logger.error("DynamoDB error updating todo %s [%s]: %s", pk, error_code, str(e))
                return Response(
                    {"error": "Failed to update todo in database"},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            except BotoCoreError as e:
                logger.error("AWS connection error updating todo %s: %s", pk, str(e))
                return Response(
                    {"error": "Database connection error"},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
            except Exception as e:  # pylint: disable=broad-exception-caught
                logger.exception("Unexpected error updating todo %s: %s", pk, str(e))
                return Response(
                    {"error": "An unexpected error occurred"},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR,
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif request.method == "DELETE":
        try:
            # Check if todo exists
            existing = db.get_todo(pk)
            if not existing:
                return Response({"error": "Todo not found"}, status=status.HTTP_404_NOT_FOUND)

            db.delete_todo(pk)
            return Response(status=status.HTTP_204_NO_CONTENT)
        except ClientError as e:
            error_code = e.response.get("Error", {}).get("Code", "Unknown")
            logger.error("DynamoDB error deleting todo %s [%s]: %s", pk, error_code, str(e))
            return Response(
                {"error": "Failed to delete todo from database"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except BotoCoreError as e:
            logger.error("AWS connection error deleting todo %s: %s", pk, str(e))
            return Response(
                {"error": "Database connection error"},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        except Exception as e:  # pylint: disable=broad-exception-caught
            logger.exception("Unexpected error deleting todo %s: %s", pk, str(e))
            return Response(
                {"error": "An unexpected error occurred"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

    return Response({"error": "Method not allowed"}, status=status.HTTP_405_METHOD_NOT_ALLOWED)


@api_view(["GET"])
def health_check(_request: Request) -> Response:
    """
    Health check endpoint.

    Verifies that the service is running and can connect to DynamoDB.

    Args:
        _request: The HTTP request object (unused, required by API decorator)

    Returns:
        Response with health status
    """
    db = get_db_client()

    health_status: Dict[str, Any] = {
        "status": "healthy",
        "dynamodb": "connected" if db.table_exists() else "disconnected",
    }

    status_code = (
        status.HTTP_200_OK if health_status["dynamodb"] == "connected" else status.HTTP_503_SERVICE_UNAVAILABLE
    )

    return Response(health_status, status=status_code)
