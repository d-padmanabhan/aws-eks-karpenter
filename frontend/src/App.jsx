import { useState, useEffect } from 'react'
import { CheckCircle2, Circle, Trash2, Plus, Edit2, X, Save, AlertCircle } from 'lucide-react'
import { todoApi } from './api/todoApi'

function App() {
  const [todos, setTodos] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [newTodo, setNewTodo] = useState({ title: '', description: '' })
  const [editingId, setEditingId] = useState(null)
  const [editForm, setEditForm] = useState({ title: '', description: '' })

  useEffect(() => {
    fetchTodos()
  }, [])

  const fetchTodos = async () => {
    try {
      setLoading(true)
      setError(null)
      const data = await todoApi.getTodos()
      setTodos(data)
    } catch (err) {
      setError('Failed to load todos. Please check your connection.')
      console.error('Error fetching todos:', err)
    } finally {
      setLoading(false)
    }
  }

  const handleCreateTodo = async (e) => {
    e.preventDefault()
    if (!newTodo.title.trim()) return

    try {
      const created = await todoApi.createTodo(newTodo)
      setTodos([created, ...todos])
      setNewTodo({ title: '', description: '' })
    } catch (err) {
      setError('Failed to create todo')
      console.error('Error creating todo:', err)
    }
  }

  const handleToggleComplete = async (todo) => {
    try {
      const updated = await todoApi.updateTodo(todo.id, {
        ...todo,
        completed: !todo.completed
      })
      setTodos(todos.map(t => t.id === todo.id ? updated : t))
    } catch (err) {
      setError('Failed to update todo')
      console.error('Error updating todo:', err)
    }
  }

  const handleDeleteTodo = async (id) => {
    if (!window.confirm('Are you sure you want to delete this todo?')) return

    try {
      await todoApi.deleteTodo(id)
      setTodos(todos.filter(t => t.id !== id))
    } catch (err) {
      setError('Failed to delete todo')
      console.error('Error deleting todo:', err)
    }
  }

  const startEditing = (todo) => {
    setEditingId(todo.id)
    setEditForm({ title: todo.title, description: todo.description || '' })
  }

  const cancelEditing = () => {
    setEditingId(null)
    setEditForm({ title: '', description: '' })
  }

  const handleUpdateTodo = async (todo) => {
    if (!editForm.title.trim()) return

    try {
      const updated = await todoApi.updateTodo(todo.id, {
        ...todo,
        title: editForm.title,
        description: editForm.description
      })
      setTodos(todos.map(t => t.id === todo.id ? updated : t))
      setEditingId(null)
      setEditForm({ title: '', description: '' })
    } catch (err) {
      setError('Failed to update todo')
      console.error('Error updating todo:', err)
    }
  }

  const stats = {
    total: todos.length,
    completed: todos.filter(t => t.completed).length,
    pending: todos.filter(t => !t.completed).length
  }

  return (
    <div className="min-h-screen py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-4xl font-bold text-slate-800 mb-2">
            Todo App
          </h1>
          <p className="text-slate-600">Production-grade task management on EKS</p>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-3 gap-4 mb-8">
          <div className="card text-center">
            <div className="text-3xl font-bold text-primary-600">{stats.total}</div>
            <div className="text-sm text-slate-600 mt-1">Total</div>
          </div>
          <div className="card text-center">
            <div className="text-3xl font-bold text-green-600">{stats.completed}</div>
            <div className="text-sm text-slate-600 mt-1">Completed</div>
          </div>
          <div className="card text-center">
            <div className="text-3xl font-bold text-amber-600">{stats.pending}</div>
            <div className="text-sm text-slate-600 mt-1">Pending</div>
          </div>
        </div>

        {/* Error Message */}
        {error && (
          <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg flex items-start gap-3">
            <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-red-800">{error}</p>
            </div>
            <button
              onClick={() => setError(null)}
              className="text-red-600 hover:text-red-800"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        )}

        {/* Create Todo Form */}
        <div className="card mb-8">
          <h2 className="text-xl font-semibold text-slate-800 mb-4">Add New Todo</h2>
          <form onSubmit={handleCreateTodo} className="space-y-4">
            <div>
              <input
                type="text"
                placeholder="What needs to be done?"
                value={newTodo.title}
                onChange={(e) => setNewTodo({ ...newTodo, title: e.target.value })}
                className="input-field"
                required
              />
            </div>
            <div>
              <textarea
                placeholder="Description (optional)"
                value={newTodo.description}
                onChange={(e) => setNewTodo({ ...newTodo, description: e.target.value })}
                className="input-field resize-none"
                rows="2"
              />
            </div>
            <button type="submit" className="btn-primary w-full flex items-center justify-center gap-2">
              <Plus className="w-5 h-5" />
              Add Todo
            </button>
          </form>
        </div>

        {/* Todo List */}
        <div className="card">
          <h2 className="text-xl font-semibold text-slate-800 mb-4">Your Todos</h2>
          
          {loading ? (
            <div className="text-center py-12">
              <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
              <p className="mt-4 text-slate-600">Loading todos...</p>
            </div>
          ) : todos.length === 0 ? (
            <div className="text-center py-12">
              <Circle className="w-16 h-16 text-slate-300 mx-auto mb-4" />
              <p className="text-slate-600">No todos yet. Create one to get started!</p>
            </div>
          ) : (
            <div className="space-y-3">
              {todos.map((todo) => (
                <div
                  key={todo.id}
                  className={`p-4 rounded-lg border transition-all duration-200 ${
                    todo.completed
                      ? 'bg-slate-50 border-slate-200'
                      : 'bg-white border-slate-300 hover:border-primary-300'
                  }`}
                >
                  {editingId === todo.id ? (
                    <div className="space-y-3">
                      <input
                        type="text"
                        value={editForm.title}
                        onChange={(e) => setEditForm({ ...editForm, title: e.target.value })}
                        className="input-field"
                        autoFocus
                      />
                      <textarea
                        value={editForm.description}
                        onChange={(e) => setEditForm({ ...editForm, description: e.target.value })}
                        className="input-field resize-none"
                        rows="2"
                      />
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleUpdateTodo(todo)}
                          className="btn-primary flex items-center gap-2 flex-1"
                        >
                          <Save className="w-4 h-4" />
                          Save
                        </button>
                        <button
                          onClick={cancelEditing}
                          className="btn-secondary flex items-center gap-2 flex-1"
                        >
                          <X className="w-4 h-4" />
                          Cancel
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-start gap-3">
                      <button
                        onClick={() => handleToggleComplete(todo)}
                        className="flex-shrink-0 mt-1 text-slate-400 hover:text-primary-600 transition-colors"
                      >
                        {todo.completed ? (
                          <CheckCircle2 className="w-6 h-6 text-green-600" />
                        ) : (
                          <Circle className="w-6 h-6" />
                        )}
                      </button>
                      
                      <div className="flex-1 min-w-0">
                        <h3
                          className={`font-medium ${
                            todo.completed
                              ? 'text-slate-500 line-through'
                              : 'text-slate-800'
                          }`}
                        >
                          {todo.title}
                        </h3>
                        {todo.description && (
                          <p
                            className={`mt-1 text-sm ${
                              todo.completed ? 'text-slate-400' : 'text-slate-600'
                            }`}
                          >
                            {todo.description}
                          </p>
                        )}
                        <p className="mt-2 text-xs text-slate-400">
                          Created: {new Date(todo.created_at).toLocaleString()}
                        </p>
                      </div>

                      <div className="flex gap-2 flex-shrink-0">
                        <button
                          onClick={() => startEditing(todo)}
                          className="p-2 text-slate-400 hover:text-primary-600 hover:bg-primary-50 rounded-lg transition-colors"
                          title="Edit"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDeleteTodo(todo.id)}
                          className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="mt-8 text-center text-sm text-slate-500">
          <p>Powered by Django, React, DynamoDB & EKS</p>
        </div>
      </div>
    </div>
  )
}

export default App
