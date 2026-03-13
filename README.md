# AI Filtering Demo App

A Phoenix LiveView application demonstrating an AI-assisted filtering pattern where users can describe filters in natural language, which are then translated into structured filter parameters using InstructorEx.

## Key Features

- **Natural Language Filtering**: Users can describe customer filters in plain English
- **Traditional UI**: Manual filter controls remain available and editable
- **Deterministic Query Layer**: Same query logic used for both AI and manual filters
- **Transparency**: Debug panel shows AI parsing results and current filter state
- **Validation**: InstructorEx handles structured output validation and retries

## Architecture

The app demonstrates this pattern:
1. User describes intent in natural language
2. InstructorEx translates intent to structured filter parameters  
3. Application validates and applies filters using deterministic query logic
4. Results are displayed with full transparency into the AI parsing process

## Setup

1. **Set OpenAI API Key**:
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. **Install dependencies and setup database**:
   ```bash
   mix setup
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Visit the app**:
   Open [`localhost:4000`](http://localhost:4000) in your browser

## Example Natural Language Queries

Try these example prompts:

- "customers who spent more than $500 and are inactive"
- "enterprise customers with open tickets"  
- "people who signed up recently but have not ordered yet"
- "customers from Uruguay who have not purchased in 6 months"
- "customers that spend a lot but haven't bought anything in a while"

## Architecture Highlights

- **Customer Schema**: Standard Ecto schema with realistic customer data
- **CustomerFilter**: Embedded schema defining available filter parameters
- **CustomerFilters**: Deterministic query composition functions
- **IntentFilters**: AI parsing layer using InstructorEx
- **CustomerLive.Index**: Main LiveView handling both manual and AI-assisted filtering

The design ensures AI is assistive rather than authoritative - users can always inspect and edit the generated filters manually.
