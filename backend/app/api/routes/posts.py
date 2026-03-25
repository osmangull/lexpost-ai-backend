from fastapi import APIRouter, HTTPException

from app.db.supabase_client import get_supabase
from app.schemas.posts import GeneratePostRequest, GeneratedPostOut
from app.services.image_service import generate_and_store_post

router = APIRouter()


@router.post("/generate", response_model=GeneratedPostOut)
async def generate_post(request: GeneratePostRequest):
    try:
        post = await generate_and_store_post(
            legal_update_id=request.legal_update_id,
            template_id=request.template_id,
            font_style=request.font_style,
            user_id=request.user_id,
            custom_text=request.custom_text,
        )
        return post
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Image generation failed: {e}")


@router.get("/user/{user_id}", response_model=list[GeneratedPostOut])
async def list_user_posts(user_id: str, limit: int = 20):
    db = get_supabase()
    result = (
        db.table("generated_posts")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .limit(limit)
        .execute()
    )
    return result.data
