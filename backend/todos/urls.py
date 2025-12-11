"""
URL patterns for todos API.
"""
from django.urls import path
from . import views

urlpatterns = [
    path('todos/', views.todo_list, name='todo-list'),
    path('todos/<str:pk>/', views.todo_detail, name='todo-detail'),
    path('health/', views.health_check, name='health-check'),
]
