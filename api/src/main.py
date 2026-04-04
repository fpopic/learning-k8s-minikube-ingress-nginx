from fastapi import FastAPI, Header, Request
from typing import Optional

# Best Practice: Explicitly define docs URL when behind a proxy
app = FastAPI(
    docs_url="/api/docs",
    openapi_url="/api/openapi.json"
)

@app.get("/api/users")
def get_users(
    x_auth_request_user: Optional[str] = Header(None),
    x_auth_request_email: Optional[str] = Header(None)
):
    # Backend SSO Pattern: oauth2-proxy handles auth and passes user info in headers
    user_info = {
        "user": x_auth_request_user or "anonymous",
        "email": x_auth_request_email or "unknown"
    }
    
    return {
        "service": "user-service",
        "authenticated_as": user_info,
        "data": ["Alice", "Bob", "Charlie"]
    }

@app.get("/api/payments")
def get_payments(
    x_auth_request_user: Optional[str] = Header(None)
):
    return {
        "service": "payment-service", 
        "authenticated_as": x_auth_request_user or "anonymous",
        "data": ["$10.00", "$25.50", "$100.00"]
    }

@app.get("/api/me")
def get_me(request: Request):
    # Print all headers for debugging the SSO pattern
    return {
        "headers": dict(request.headers),
        "message": "This endpoint shows all headers passed to the backend (including SSO headers)"
    }
