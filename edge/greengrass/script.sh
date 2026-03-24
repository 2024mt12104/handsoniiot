$cid = '6a3adad2cac458dace1df087facb65a8f26c0d2957b7157aac2c011661413bfc'

# Prefer exported env credentials; fall back to aws config values.
$ak = if ($env:AWS_ACCESS_KEY_ID) { $env:AWS_ACCESS_KEY_ID } else { aws configure get aws_access_key_id }
$sk = if ($env:AWS_SECRET_ACCESS_KEY) { $env:AWS_SECRET_ACCESS_KEY } else { aws configure get aws_secret_access_key }
$st = if ($env:AWS_SESSION_TOKEN) { $env:AWS_SESSION_TOKEN } else { aws configure get aws_session_token }

if (-not $ak -or -not $sk) {
	Write-Error 'Host AWS credentials not available via aws configure get.'
	exit 1
}

if ($ak.StartsWith('ASIA') -and -not $st) {
  Write-Error 'Temporary AWS credentials detected but AWS_SESSION_TOKEN is missing.'
  exit 1
}

# Validate credentials before invoking docker exec to fail with a clear message.
aws sts get-caller-identity | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Error 'Host AWS credentials are invalid or expired. Refresh credentials and retry.'
  exit 1
}

$envs = @(
	'-e', "AWS_ACCESS_KEY_ID=$ak",
	'-e', "AWS_SECRET_ACCESS_KEY=$sk",
	'-e', "AWS_DEFAULT_REGION=ap-south-1"
)

if ($st) {
	$envs += @('-e', "AWS_SESSION_TOKEN=$st")
}

docker exec @envs $cid bash -lc "
yum install -y unzip wget shadow-utils less systemd systemd-sysv kernel-libbpf which procps-ng java awscli &&
curl -s https://d2s8p88vqu9w66.cloudfront.net/releases/greengrass-nucleus-latest.zip > greengrass-nucleus-latest.zip &&
unzip -o greengrass-nucleus-latest.zip -d GreengrassInstaller &&
(getent group ggc_group || groupadd -r ggc_group) &&
(id -u ggc_user >/dev/null 2>&1 || useradd -r -m -g ggc_group ggc_user) &&
java -Droot='/greengrass/v2' -Dlog.store=FILE -jar ./GreengrassInstaller/lib/Greengrass.jar \
  --aws-region ap-south-1 \
  --thing-name GreengrassDevice2 \
  --thing-group-name GreengrassQucikStartGroup \
  --component-default-user ggc_user:ggc_group \
  --provision true \
  --setup-system-service false \
  --deploy-dev-tools true
"