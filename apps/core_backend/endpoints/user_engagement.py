# Navi4All
# Copyright (C) Navi4All contributors
# Maintainer: Plan4Better GmbH
#
# SPDX-License-Identifier: AGPL-3.0-only
#
# Licensed under the GNU Affero General Public License, Version 3 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.gnu.org/licenses/agpl-3.0.en.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

