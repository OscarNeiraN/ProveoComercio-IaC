output "trail_arn" {
  value = one(aws_cloudtrail.main[*].arn)
}

output "bucket_name" {
  value = one(aws_s3_bucket.trail[*].id)
}
