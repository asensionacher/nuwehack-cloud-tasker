output "api_invoke_url" {
  description = "API invoke url."
  value       = aws_api_gateway_deployment.taskapistageprod.invoke_url
}

output "api_rest_api_id" {
  description = "API invoke url."
  value       = aws_api_gateway_deployment.taskapistageprod.rest_api_id
}