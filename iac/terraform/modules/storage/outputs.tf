output "alb_logs_bucket" {
  value = aws_s3_bucket.alb_logs.id
}

output "alb_logs_bucket_arn" {
  value = aws_s3_bucket.alb_logs.arn
}

output "app_data_bucket" {
  value = aws_s3_bucket.app_data.id
}

output "app_data_bucket_arn" {
  value = aws_s3_bucket.app_data.arn
}
