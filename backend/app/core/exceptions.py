from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse


async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={"detail": "Erro interno do servidor.", "error": str(exc)},
    )


class AppError(HTTPException):
    pass
