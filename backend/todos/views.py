"""
API views for Todo operations.
"""
from rest_framework import status
from rest_framework.decorators import api_view
from rest_framework.response import Response
from .dynamodb import get_db_client
from .serializers import TodoSerializer
import logging

logger = logging.getLogger(__name__)


@api_view(['GET', 'POST'])
def todo_list(request):
    """
    List all todos or create a new todo.
    """
    db = get_db_client()
    
    if request.method == 'GET':
        try:
            todos = db.list_todos()
            serializer = TodoSerializer(todos, many=True)
            return Response(serializer.data)
        except Exception as e:
            logger.error(f"Error listing todos: {str(e)}")
            return Response(
                {'error': 'Failed to retrieve todos'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    elif request.method == 'POST':
        serializer = TodoSerializer(data=request.data)
        if serializer.is_valid():
            try:
                todo = db.create_todo(
                    title=serializer.validated_data['title'],
                    description=serializer.validated_data.get('description', ''),
                    completed=serializer.validated_data.get('completed', False)
                )
                return Response(
                    TodoSerializer(todo).data,
                    status=status.HTTP_201_CREATED
                )
            except Exception as e:
                logger.error(f"Error creating todo: {str(e)}")
                return Response(
                    {'error': 'Failed to create todo'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET', 'PUT', 'DELETE'])
def todo_detail(request, pk):
    """
    Retrieve, update or delete a todo.
    """
    db = get_db_client()
    
    if request.method == 'GET':
        try:
            todo = db.get_todo(pk)
            if not todo:
                return Response(
                    {'error': 'Todo not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            serializer = TodoSerializer(todo)
            return Response(serializer.data)
        except Exception as e:
            logger.error(f"Error retrieving todo {pk}: {str(e)}")
            return Response(
                {'error': 'Failed to retrieve todo'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    elif request.method == 'PUT':
        serializer = TodoSerializer(data=request.data)
        if serializer.is_valid():
            try:
                # Check if todo exists
                existing = db.get_todo(pk)
                if not existing:
                    return Response(
                        {'error': 'Todo not found'},
                        status=status.HTTP_404_NOT_FOUND
                    )
                
                # Update the todo
                updated_todo = db.update_todo(
                    pk,
                    title=serializer.validated_data.get('title'),
                    description=serializer.validated_data.get('description'),
                    completed=serializer.validated_data.get('completed')
                )
                return Response(TodoSerializer(updated_todo).data)
            except Exception as e:
                logger.error(f"Error updating todo {pk}: {str(e)}")
                return Response(
                    {'error': 'Failed to update todo'},
                    status=status.HTTP_500_INTERNAL_SERVER_ERROR
                )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    elif request.method == 'DELETE':
        try:
            # Check if todo exists
            existing = db.get_todo(pk)
            if not existing:
                return Response(
                    {'error': 'Todo not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            db.delete_todo(pk)
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Exception as e:
            logger.error(f"Error deleting todo {pk}: {str(e)}")
            return Response(
                {'error': 'Failed to delete todo'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


@api_view(['GET'])
def health_check(request):
    """Health check endpoint."""
    db = get_db_client()
    
    health_status = {
        'status': 'healthy',
        'dynamodb': 'connected' if db.table_exists() else 'disconnected'
    }
    
    status_code = status.HTTP_200_OK if health_status['dynamodb'] == 'connected' else status.HTTP_503_SERVICE_UNAVAILABLE
    
    return Response(health_status, status=status_code)
