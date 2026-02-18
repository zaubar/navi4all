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

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from endpoints.routing import router as routing_router
from endpoints.geocoding import router as geocoding_router
from endpoints.user_engagement import router as user_engagement_router
from core.config import settings

app = FastAPI(
    title="Navi4All Core Backend API",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(routing_router, prefix=settings.API_VERSION)
app.include_router(geocoding_router, prefix=settings.API_VERSION)
app.include_router(user_engagement_router, prefix=settings.API_VERSION)

@app.get("/")
async def root():
    return {"message": "Welcome to the Navi4All Core Backend API"}
