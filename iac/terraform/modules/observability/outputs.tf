output "cloudtrail_name" {
  value = aws_cloudtrail.this.name
}

output "cloudtrail_bucket" {
  value = aws_s3_bucket.trail.id
}

output "cloudtrail_log_group" {
  value = aws_cloudwatch_log_group.trail.name
}

output "security_alarms_topic_arn" {
  value = aws_sns_topic.alarms.arn
}
