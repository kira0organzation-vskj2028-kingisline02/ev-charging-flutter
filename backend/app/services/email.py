import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from loguru import logger
from ..config import settings

def send_otp_email(to_email: str, code: str) -> bool:
    # Always log code to server console as fallback
    logger.info(f"[OTP SERVICE] Verification code for {to_email}: {code}")
    
    if not settings.smtp_host or not settings.smtp_user or not settings.smtp_password:
        logger.warning(
            f"SMTP not configured (host='{settings.smtp_host}', user='{settings.smtp_user}'). "
            f"OTP code for {to_email} logged above."
        )
        return True

    clean_user = settings.smtp_user.strip()
    clean_pwd = settings.smtp_password.strip()
    clean_host = settings.smtp_host.strip()

    msg = MIMEMultipart("alternative")
    msg["From"] = f"ChargeBridge <{clean_user}>"
    msg["To"] = to_email
    msg["Subject"] = f"{code} is your ChargeBridge verification code"

    text_body = f"""Hello,

Your verification code for ChargeBridge is: {code}

This code will expire in 10 minutes. If you did not request this, please ignore this email.

Best regards,
ChargeBridge Team
"""

    html_body = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: 'Helvetica Neue', Arial, sans-serif; background-color: #F7F4EE; margin: 0; padding: 24px; color: #162518; }}
    .card {{ max-width: 480px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #E0D8CB; padding: 32px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); }}
    .header {{ font-size: 20px; font-weight: bold; color: #1B4332; margin-bottom: 8px; }}
    .code-box {{ background: #F7F4EE; border: 2px dashed #1B4332; border-radius: 12px; padding: 18px; text-align: center; margin: 24px 0; }}
    .code {{ font-size: 34px; font-weight: 800; letter-spacing: 6px; color: #7C3AED; }}
    .footer {{ font-size: 12px; color: #768678; margin-top: 24px; border-top: 1px solid #EAE5DC; padding-top: 16px; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="header">ChargeBridge EV Sharing</div>
    <p>Use the following code to verify your account:</p>
    <div class="code-box">
      <div class="code">{code}</div>
    </div>
    <p>This code will expire in <strong>10 minutes</strong>. Do not share this code with anyone.</p>
    <div class="footer">
      If you did not request this code, you can safely ignore this email.
    </div>
  </div>
</body>
</html>"""

    msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    # Attempt 1: Port 465 with direct SSL (most reliable on cloud VPS/Docker)
    try:
        logger.info(f"Connecting to {clean_host}:465 (SSL)...")
        with smtplib.SMTP_SSL(clean_host, 465, timeout=12) as server:
            server.login(clean_user, clean_pwd)
            server.send_message(msg)
        logger.info(f"Verification email sent successfully via SSL (465) to {to_email}")
        return True
    except Exception as ssl_err:
        logger.warning(f"Port 465 SSL failed ({ssl_err}), trying Port 587 STARTTLS...")

    # Attempt 2: Port 587 with STARTTLS fallback
    try:
        logger.info(f"Connecting to {clean_host}:587 (STARTTLS)...")
        with smtplib.SMTP(clean_host, 587, timeout=12) as server:
            server.ehlo()
            server.starttls()
            server.ehlo()
            server.login(clean_user, clean_pwd)
            server.send_message(msg)
        logger.info(f"Verification email sent successfully via STARTTLS (587) to {to_email}")
        return True
    except Exception as tls_err:
        logger.error(f"Failed to send email to {to_email} via both SSL and STARTTLS: {tls_err}")
        return False
