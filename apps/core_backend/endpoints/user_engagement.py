from fastapi import APIRouter, HTTPException
from schemas.user_engagement import UserEngagementEvent
from services.adaptors.user_engagement import UserEngagementAdaptor


router = APIRouter(prefix="/user-engagement")
adaptor = UserEngagementAdaptor()


@router.get("/event", response_model=UserEngagementEvent)
async def get_event():
	try:
		return adaptor.get_event()
	except (FileNotFoundError, ValueError, RuntimeError) as exc:
		raise HTTPException(status_code=404, detail=str(exc))

