from fastapi import APIRouter, HTTPException
from fastapi.responses import Response

from app.schemas.posts import GeneratePostRequest, ManualPostRequest
from app.services.image_service import generate_post_image, generate_manual_post_image

router = APIRouter()


@router.post("/generate")
async def generate_post(request: GeneratePostRequest):
    try:
        image_bytes = await generate_post_image(
            legal_update_id=request.legal_update_id,
            template_id=request.template_id,
            font_style=request.font_style,
            custom_text=request.custom_text,
            user_image_base64=request.user_image_base64,
        )
        return Response(content=image_bytes, media_type="image/jpeg")
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image generation failed: {e}")


@router.post("/generate-manual")
async def generate_manual(request: ManualPostRequest):
    try:
        image_bytes = await generate_manual_post_image(
            user_image_base64=request.user_image_base64,
            custom_text=request.custom_text,
            font_style=request.font_style,
        )
        return Response(content=image_bytes, media_type="image/jpeg")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image generation failed: {e}")
