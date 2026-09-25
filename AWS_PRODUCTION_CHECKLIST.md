Foundation & Security
✅ AWS account setup
✅ Billing budget
✅ Root MFA
✅ IAM admin + MFA
🔄 Production VPC ← abhi yahan
Security Groups
IAM Roles for ECS/services
🟡 Database
RDS PostgreSQL production setup     -------
RDS security/private networking
Database migration 0001–0016
Production database initial configuration
🟠 Storage & Secrets
S3 buckets for rider documents
S3 security / private access
Secrets Manager
Production environment variables
🔵 Backend Deployment
Backend Dockerfile / production image
ECR repository
Push NestJS Docker image to ECR
ECS/Fargate cluster
ECS service + task definition
Connect ECS → RDS/S3/Secrets
🟣 Internet / HTTPS
Application Load Balancer
Security groups
Domain / Route 53
SSL certificate / ACM
HTTPS API endpoint
🟤 Admin Panel
Admin production build
Admin hosting — S3/CloudFront
Connect Admin → production API
Admin domain + HTTPS
🔴 External Services
MSG91 OTP/SMS
Firebase FCM notifications
Google Maps / Routes API
Payment gateway
Payment webhooks
🟧 Application-specific production fixes
Finance freeze → DELIVERED
Real S3 document upload API
Remove tracked demo admin password
Production configuration validation
Logging + monitoring
🛡️ Production safety
CloudWatch alarms/logs
AWS WAF
Backup configuration
RDS backup/retention
Cost monitoring
Security review
🚀 Final launch
Backend production testing
Admin production testing
Customer Flutter production configuration
Rider Flutter production configuration
Release signing
Android/iOS production builds
End-to-end testing
Final production launch