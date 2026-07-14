# back-office-ui (port 8104): Streamlit treasury/finance console; uses
# Streamlit's built-in health endpoint (_stcore/health), which returns
# 200 with an empty body.

GET http://localhost:8104/_stcore/health
HTTP 200
