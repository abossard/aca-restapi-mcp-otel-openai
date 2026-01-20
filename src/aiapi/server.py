"""
AI-Enhanced REST API with OpenTelemetry, Azure OpenAI, and Azure AI Search.

This FastAPI application provides intelligent responses using Azure services
with comprehensive observability through OpenTelemetry.
"""

import os
import structlog
from azure.monitor.opentelemetry import configure_azure_monitor
from contextlib import asynccontextmanager
from typing import Dict, List, Optional

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import get_swagger_ui_html
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from azure.identity import DefaultAzureCredential
from azure.search.documents.aio import SearchClient
from openai import AsyncAzureOpenAI
from opentelemetry import trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import ConsoleSpanExporter, SimpleSpanProcessor
from opentelemetry.sdk.resources import Resource


# Configure structured logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.processors.JSONRenderer()
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    wrapper_class=structlog.stdlib.BoundLogger,
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger(__name__)


def _is_truthy(value: Optional[str]) -> bool:
    """Return True when the string is set to a common truthy value."""
    if value is None:
        return False
    return value.strip().lower() in {"1", "true", "yes", "on"}

def setup_telemetry():
    """Configure OpenTelemetry tracing.

    Logic:
      - If Application Insights connection string present, use Azure Monitor distro (adds AI exporters + default instr).
      - Otherwise fall back to console exporting for local development visibility.
    """
    ai_conn = os.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING")

    if ai_conn:
        # Azure Monitor OpenTelemetry Distro handles tracer provider + instrumentation.
        configure_azure_monitor(connection_string=ai_conn, logger_name="aiapi")
        tracer = trace.get_tracer(__name__)
        logger.info("Telemetry initialized via Azure Monitor OpenTelemetry Distro")
        return tracer

    # Local development path: emit spans to stdout for easy inspection.
    resource = Resource.create({
        "service.name": os.getenv("OTEL_SERVICE_NAME", "aca-restapi-mcp-otel-openai"),
        "service.version": os.getenv("OTEL_SERVICE_VERSION", "1.0.0"),
    })
    provider = TracerProvider(resource=resource)
    trace.set_tracer_provider(provider)
    tracer = trace.get_tracer(__name__)

    console_exporter = ConsoleSpanExporter()
    span_processor = SimpleSpanProcessor(console_exporter)
    provider.add_span_processor(span_processor)
    logger.info("Telemetry initialized with console exporter (local mode)")
    return tracer

# Initialize tracer only when explicitly enabled
_enable_otel = _is_truthy(os.getenv("ENABLE_OTEL"))
if _enable_otel:
    tracer = setup_telemetry()
else:
    tracer = trace.get_tracer(__name__)
    logger.info("OpenTelemetry disabled", enable_otel=os.getenv("ENABLE_OTEL"))

# Application state
class AppState:
    def __init__(self):
        self.openai_client: Optional[AsyncAzureOpenAI] = None
        self.search_client: Optional[SearchClient] = None
        self.credential: Optional[DefaultAzureCredential] = None

app_state = AppState()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan management."""
    with tracer.start_as_current_span("app_startup"):
        logger.info("Starting AI-Enhanced REST API")
        
        # Initialize Azure credentials
        app_state.credential = DefaultAzureCredential()
        
        # Initialize Azure OpenAI client
        azure_openai_endpoint = os.getenv("AZURE_OPENAI_ENDPOINT")
        if azure_openai_endpoint:
            # azure_ad_token_provider must be a callable that returns the token string
            def get_token() -> str:
                return app_state.credential.get_token("https://cognitiveservices.azure.com/.default").token
            
            app_state.openai_client = AsyncAzureOpenAI(
                azure_endpoint=azure_openai_endpoint,
                azure_ad_token_provider=get_token,
                api_version="2024-02-01"
            )
            logger.info("Azure OpenAI client initialized")
        
        # Initialize Azure AI Search client
        search_endpoint = os.getenv("AZURE_SEARCH_ENDPOINT")
        search_index = os.getenv("AZURE_SEARCH_INDEX", "documents")
        if search_endpoint:
            app_state.search_client = SearchClient(
                endpoint=search_endpoint,
                index_name=search_index,
                credential=app_state.credential
            )
            logger.info("Azure AI Search client initialized")
    
    yield
    
    with tracer.start_as_current_span("app_shutdown"):
        logger.info("Shutting down AI-Enhanced REST API")
        if app_state.search_client:
            await app_state.search_client.close()

# FastAPI app
app = FastAPI(
    title="AI-Enhanced REST API",
    description="REST API with Azure OpenAI and AI Search integration",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Instrument FastAPI with OpenTelemetry only when enabled
if _enable_otel:
    FastAPIInstrumentor.instrument_app(app)
    RequestsInstrumentor().instrument()

# Pydantic models
class QueryRequest(BaseModel):
    query: str = Field(..., description="User query for AI processing")
    max_results: int = Field(default=5, ge=1, le=20, description="Maximum search results")
    temperature: float = Field(default=0.7, ge=0.0, le=1.0, description="AI response creativity")

class SearchResult(BaseModel):
    title: str
    content: str
    score: float

class AIResponse(BaseModel):
    answer: str
    sources: List[SearchResult]
    tokens_used: int

class HealthResponse(BaseModel):
    status: str
    services: Dict[str, bool]

@app.get("/", include_in_schema=False)
async def root_redirect():
    return RedirectResponse(url="/api-explorer")

# Custom interactive documentation endpoint using Swagger UI
@app.get("/api-explorer", include_in_schema=False)
async def custom_swagger_ui():
    return get_swagger_ui_html(
        openapi_url=app.openapi_url,
        title=f"{app.title} - API Explorer",
        swagger_ui_parameters={
            "displayRequestDuration": True,
            "filter": True,
        },
    )


# Dependencies
async def get_openai_client() -> AsyncAzureOpenAI:
    if not app_state.openai_client:
        raise HTTPException(status_code=503, detail="Azure OpenAI service not available")
    return app_state.openai_client

async def get_search_client() -> SearchClient:
    if not app_state.search_client:
        raise HTTPException(status_code=503, detail="Azure AI Search service not available")
    return app_state.search_client

# Routes
@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    with tracer.start_as_current_span("health_check"):
        services = {
            "openai": app_state.openai_client is not None,
            "search": app_state.search_client is not None,
        }
        
        status = "healthy" if all(services.values()) else "degraded"
        
        logger.info("Health check performed", status=status, services=services)
        
        return HealthResponse(status=status, services=services)

@app.get("/")
async def root():
    """Root endpoint."""
    return {"message": "AI-Enhanced REST API", "version": "1.0.0"}

@app.post("/query", response_model=AIResponse)
async def query_ai(
    request: QueryRequest,
    openai_client: AsyncAzureOpenAI = Depends(get_openai_client),
    search_client: SearchClient = Depends(get_search_client)
):
    """Process AI query with search context."""
    with tracer.start_as_current_span("query_ai") as span:
        span.set_attribute("query.text", request.query)
        span.set_attribute("query.max_results", request.max_results)
        
        logger.info("Processing AI query", query=request.query)
        
        try:
            # Search for relevant documents
            with tracer.start_as_current_span("search_documents"):
                search_results = await search_client.search(
                    search_text=request.query,
                    top=request.max_results
                )
                
                sources = []
                context_parts = []
                
                async for result in search_results:
                    sources.append(SearchResult(
                        title=result.get("title", "Unknown"),
                        content=result.get("content", "")[:500],  # Truncate for context
                        score=result.get("@search.score", 0.0)
                    ))
                    context_parts.append(result.get("content", "")[:1000])
                
                context = "\n\n".join(context_parts[:3])  # Use top 3 results for context
            
            # Generate AI response
            with tracer.start_as_current_span("generate_response"):
                # Adapt prompt based on whether we have relevant documents
                if context.strip():
                    system_prompt = """You are a helpful assistant that answers questions based on the provided context. 
                    Use the context to provide accurate, grounded answers. If the context only partially answers the question, 
                    supplement with your knowledge but clearly indicate what comes from the documents vs your general knowledge."""
                    
                    user_prompt = f"""Context from search results:
                    {context}
                    
                    Question: {request.query}
                    
                    Please provide a comprehensive answer based on the context above."""
                else:
                    system_prompt = """You are a helpful AI assistant. Answer questions directly and helpfully. 
                    Since no relevant documents were found in the knowledge base, use your general knowledge to answer."""
                    
                    user_prompt = f"""Question: {request.query}
                    
                    Note: No relevant documents were found in the knowledge base. Please answer based on your general knowledge."""
                
                response = await openai_client.chat.completions.create(
                    model="gpt-4o",  # Configured model name
                    messages=[
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    temperature=request.temperature,
                    max_tokens=1000
                )
                
                ai_answer = response.choices[0].message.content
                tokens_used = response.usage.total_tokens if response.usage else 0
            
            span.set_attribute("response.tokens_used", tokens_used)
            span.set_attribute("response.sources_count", len(sources))
            
            logger.info(
                "AI query processed successfully",
                tokens_used=tokens_used,
                sources_count=len(sources)
            )
            
            return AIResponse(
                answer=ai_answer,
                sources=sources,
                tokens_used=tokens_used
            )
            
        except Exception as e:
            span.set_attribute("error", str(e))
            logger.error("Error processing AI query", error=str(e), query=request.query)
            raise HTTPException(status_code=500, detail=f"Query processing failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    
    port = int(os.getenv("PORT", "8000"))
    host = os.getenv("HOST", "0.0.0.0")
    
    logger.info("Starting server", host=host, port=port)
    
    uvicorn.run(
        "server:app",
        host=host,
        port=port,
        reload=True,
        log_config=None  # Use structlog instead
    )
