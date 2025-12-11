# DynamoDB Table for Todos
resource "aws_dynamodb_table" "todos" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  # Enable encryption at rest
  server_side_encryption {
    enabled = true
  }

  # Enable TTL (optional, not used in this app but good practice)
  ttl {
    enabled        = false
    attribute_name = ""
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

# DynamoDB table autoscaling (optional, only if using provisioned capacity)
# Commented out since we're using PAY_PER_REQUEST mode
# resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
#   max_capacity       = 100
#   min_capacity       = 5
#   resource_id        = "table/${aws_dynamodb_table.todos.name}"
#   scalable_dimension = "dynamodb:table:ReadCapacityUnits"
#   service_namespace  = "dynamodb"
# }
