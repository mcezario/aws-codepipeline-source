resource "aws_api_gateway_rest_api" "api-sample" {
  name        = "Api Name"
  description = "-- description --"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
  disable_execute_api_endpoint = false # In production, this value should be true
}

resource "aws_api_gateway_request_validator" "request-validator" {
  name                        = "request-validator"
  rest_api_id                 = aws_api_gateway_rest_api.api-sample.id
  validate_request_body       = true
  validate_request_parameters = true
}

locals {
  models = tolist(toset([for k,v in var.MAPPING : v.model]))
}

resource "aws_api_gateway_model" "model" {
  count = length(local.models)
  rest_api_id  = aws_api_gateway_rest_api.api-sample.id
  name         = "${replace(basename(element(local.models, count.index)), ".json", "")}"
  description  = "JSON schema that represents a request"
  content_type = "application/json"

  schema = file(element(local.models, count.index))
}

resource "aws_api_gateway_resource" "resource" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  parent_id   = aws_api_gateway_rest_api.api-sample.root_resource_id
  path_part   = "${var.MAPPING[count.index].key}"
}

resource "aws_api_gateway_method" "method" {
  count = length(var.MAPPING)
  rest_api_id   = aws_api_gateway_rest_api.api-sample.id
  resource_id   = aws_api_gateway_resource.resource[count.index].id
  request_validator_id = aws_api_gateway_request_validator.request-validator.id
  http_method   = "POST"
  authorization = "NONE"
  request_models = {
      "application/json": "${replace(basename(element(local.models, count.index)), ".json", "")}"
  }
}

resource "aws_api_gateway_method_response" "response_200" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "response_422" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  response_models = {
      "application/json": "Error"
  }
  status_code = "422"
}

resource "aws_api_gateway_method_response" "response_500" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  status_code = "500"
}

resource "aws_api_gateway_integration" "integration" {
  count = length(var.MAPPING)
  rest_api_id          = aws_api_gateway_rest_api.api-sample.id
  resource_id          = aws_api_gateway_resource.resource[count.index].id
  http_method          = aws_api_gateway_method.method[count.index].http_method
  type                 = "HTTP"
  uri                  = "https://$${stageVariables.INTEGRATION_HOST}/topics/${var.MAPPING[count.index].key}"
  integration_http_method = "POST"
  passthrough_behavior = "WHEN_NO_TEMPLATES"
  request_parameters = {
      "integration.request.header.Accept" = "' '",
      "integration.request.header.Content-Type" = "'application/vnd.kafka.json.v2+json'" 
    }
  
  # Transforms the incoming XML request to JSON
  request_templates = {
    "application/json" = file(var.MAPPING[count.index].vtl)
  }
}

resource "aws_api_gateway_integration_response" "integrationResponse_200" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  status_code = aws_api_gateway_method_response.response_200[count.index].status_code
  selection_pattern = "2\\d{2}"
}

resource "aws_api_gateway_integration_response" "integrationResponse_400" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  status_code = aws_api_gateway_method_response.response_422[count.index].status_code
  selection_pattern = "4\\d{2}"
  response_templates = {
      "text/plain" = file("mappings/vtls/generic-error.vtl")
  }
}

resource "aws_api_gateway_integration_response" "integrationResponse_500" {
  count = length(var.MAPPING)
  rest_api_id = aws_api_gateway_rest_api.api-sample.id
  resource_id = aws_api_gateway_resource.resource[count.index].id
  http_method = aws_api_gateway_method.method[count.index].http_method
  status_code = aws_api_gateway_method_response.response_500[count.index].status_code
  selection_pattern = "5\\d{2}"
  response_templates = {
      "text/plain" = file("mappings/vtls/generic-error.vtl")
  }
}
