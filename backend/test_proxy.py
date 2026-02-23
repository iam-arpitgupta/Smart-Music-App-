import httpx
import asyncio

async def test():
    async with httpx.AsyncClient() as client:
        resp = await client.get("http://127.0.0.1:8000/api/v1/stream/TROFVicWrTE", headers={"Range": "bytes=0-"})
        print(f"Status: {resp.status_code}")
        print("Headers:")
        for k, v in resp.headers.items():
            print(f"  {k}: {v}")

asyncio.run(test())
