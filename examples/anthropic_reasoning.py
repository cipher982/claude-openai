"""Bridge Claude-style effort settings to OpenAI Responses reasoning.

Claude Code sends Anthropic `/v1/messages` requests with:
- `thinking={"type": "adaptive"}`
- `output_config={"effort": "low|medium|high|max"}`

Some LiteLLM Anthropic -> Responses paths do not forward `output_config.effort`
to OpenAI. This callback fills that gap by injecting
`reasoning={"effort": ...}` before the provider call.
"""

from typing import Literal, Optional, Union

from litellm.caching import DualCache
from litellm.integrations.custom_logger import CustomLogger
from litellm.proxy._types import UserAPIKeyAuth


EFFORT_MAP = {
    "none": "none",
    "low": "low",
    "medium": "medium",
    "high": "high",
    "max": "xhigh",
    "xhigh": "xhigh",
}


class AnthropicReasoningBridge(CustomLogger):
    """Translate Anthropic effort controls into OpenAI Responses reasoning."""

    @staticmethod
    def _is_target_request(request_route: str, model: object) -> bool:
        return request_route.startswith("/v1/messages") and isinstance(model, str) and model.startswith("gpt-5")

    async def async_pre_call_hook(
        self,
        user_api_key_dict: UserAPIKeyAuth,
        cache: DualCache,
        data: dict,
        call_type: Literal[
            "completion",
            "text_completion",
            "embeddings",
            "image_generation",
            "moderation",
            "audio_transcription",
        ],
    ) -> Optional[Union[dict, str]]:
        request_route = user_api_key_dict.request_route or ""
        model = data.get("model")
        if not self._is_target_request(request_route, model):
            return data

        reasoning = data.get("reasoning")
        if isinstance(reasoning, dict) and reasoning.get("effort"):
            return data

        output_config = data.get("output_config")
        if not isinstance(output_config, dict):
            return data

        raw_effort = output_config.get("effort")
        if not isinstance(raw_effort, str):
            return data

        mapped_effort = EFFORT_MAP.get(raw_effort.strip().lower())
        if mapped_effort is None:
            return data

        data["reasoning"] = {"effort": mapped_effort}
        return data


proxy_handler_instance = AnthropicReasoningBridge()
