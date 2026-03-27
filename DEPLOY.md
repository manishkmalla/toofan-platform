# TooFan Platform — AWS Deployment Guide

## Provisioned Resources (already created)

| Resource | Value |
|----------|-------|
| AWS Account | 041808556268 |
| AWS Profile | aws-manish |
| Region | us-east-1 |
| EC2 Instance | i-00fb40b770d87cd42 |
| EC2 Public IP | **52.90.193.185** |
| EC2 Key Pair | `toofan-keypair.pem` (in project root) |
| Security Group | sg-0963d52bd45779c08 |
| S3 Bucket | toofan-uploads-041808556268 |
| ECR Backend | 041808556268.dkr.ecr.us-east-1.amazonaws.com/toofan-backend |
| ECR Frontend | 041808556268.dkr.ecr.us-east-1.amazonaws.com/toofan-frontend |
| IAM OIDC Role | arn:aws:iam::041808556268:role/GitHubActionsRole |

## Architecture

```
Internet
   │
   ▼
EC2 52.90.193.185 (t3.small, us-east-1)
   ├── toofan-frontend  (nginx:80)   ◄── serves React SPA, proxies /api & /socket.io
   ├── toofan-backend   (node:5000)  ◄── Express + Socket.IO API
   └── postgres         (pg:5432)    ◄── PostgreSQL database

S3: toofan-uploads-041808556268  ◄── driver/restaurant image uploads
ECR: 041808556268.dkr.ecr.us-east-1.amazonaws.com  ◄── Docker image registry
```

---

## Step 1 — Configure environment variables

```bash
cp .env.production.example .env
# Edit .env and fill in ALL values
```

Generate JWT secrets:
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
# Run twice — once for JWT_SECRET, once for JWT_REFRESH_SECRET
```

Make sure to set in `.env`:
```
AWS_S3_BUCKET=toofan-uploads-041808556268
AWS_REGION=us-east-1
UPLOAD_DRIVER=s3
```

---

## Step 2 — Add GitHub Secret (one secret only)

Since CI/CD uses OIDC (no static keys needed), you only need to add **2 secrets**:

In your GitHub repo → **Settings → Secrets → Actions**:

| Secret | Value |
|--------|-------|
| `EC2_HOST` | `52.90.193.185` |
| `EC2_SSH_KEY` | Full contents of `toofan-keypair.pem` |

---

## Step 3 — Copy docker-compose.yml and .env to EC2

```bash
scp -i toofan-keypair.pem docker-compose.yml ec2-user@52.90.193.185:~/toofan-platform/
scp -i toofan-keypair.pem .env              ec2-user@52.90.193.185:~/toofan-platform/
```

---

## Step 4 — First deployment

Push to the `main` branch to trigger GitHub Actions:

```bash
git add .
git commit -m "add AWS deployment config"
git push origin main
```

GitHub Actions will:
1. Build backend and frontend Docker images
2. Push to ECR
3. SSH into EC2 and run `docker compose up`
4. Run Prisma migrations automatically

---

## Step 5 — Seed the database (first time only)

```bash
ssh -i toofan-keypair.pem ec2-user@52.90.193.185
cd ~/toofan-platform
docker compose exec toofan-backend node prisma/seed.js
```

---

## Useful commands on the EC2 instance

```bash
# View running containers
docker compose ps

# View backend logs
docker compose logs -f toofan-backend

# View frontend logs
docker compose logs -f toofan-frontend

# Restart a service
docker compose restart toofan-backend

# Open Prisma Studio (then SSH tunnel to access locally)
docker compose exec toofan-backend npx prisma studio
```

---

## HTTPS / Custom Domain (optional)

To add SSL with a custom domain:

1. Point your domain's A record to the EC2 public IP
2. SSH into EC2 and install Certbot:
   ```bash
   sudo yum install -y certbot
   sudo certbot certonly --standalone -d yourdomain.com
   ```
3. Update `toofan-frontend/nginx.conf` to redirect HTTP to HTTPS and serve the cert.

---

## Cost estimate (ap-south-1 Mumbai)

| Resource | Cost |
|----------|------|
| EC2 t3.small | ~$15/month |
| S3 (first 50GB) | ~$1/month |
| ECR (first 500MB) | Free |
| Data transfer | ~$1–5/month |
| **Total** | **~$17–21/month** |

---

## IAM Permissions required for deployment

The IAM user needs these policies:
- `AmazonEC2ContainerRegistryFullAccess`
- `AmazonS3FullAccess` (or scoped to your bucket)
- `AmazonEC2FullAccess` (only for initial setup, can restrict after)
