# Imago MCP Server

An MCP (Model Context Protocol) server that provides access to multiple AI image generation services through the [imago](https://github.com/theStranjer/imago) gem.

## Features

- Generate images using OpenAI (DALL-E), Google Gemini (Imagen), or xAI (Grok)
- Edit images using input images (OpenAI and Gemini only)
- List available models for each provider
- Unified interface across all providers
- stdio transport for easy integration with MCP clients

## Requirements

- Ruby 3.0 or higher
- The `imago` gem

## Installation

### macOS

1. Install Ruby (if not already installed):
   ```bash
   brew install ruby
   ```

2. Clone this repository:
   ```bash
   git clone https://github.com/theStranjer/imago-mcp.git
   cd imago-mcp
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Make the server executable:
   ```bash
   chmod +x imago_mcp_server.rb
   ```

### Linux

1. Install Ruby (if not already installed):
   ```bash
   # Debian/Ubuntu
   sudo apt-get install ruby ruby-dev

   # Fedora
   sudo dnf install ruby ruby-devel

   # Arch
   sudo pacman -S ruby
   ```

2. Clone this repository:
   ```bash
   git clone https://github.com/theStranjer/imago-mcp.git
   cd imago-mcp
   ```

3. Install dependencies:
   ```bash
   bundle install
   ```

4. Make the server executable:
   ```bash
   chmod +x imago_mcp_server.rb
   ```

### Windows

1. Install Ruby using [RubyInstaller](https://rubyinstaller.org/). Download and run the installer, selecting the option to add Ruby to your PATH.

2. Clone this repository:
   ```cmd
   git clone https://github.com/theStranjer/imago-mcp.git
   cd imago-mcp
   ```

3. Install dependencies:
   ```cmd
   bundle install
   ```

## Configuration

Set up API keys for the providers you want to use:

### macOS / Linux

```bash
export OPENAI_API_KEY="your-openai-key"
export GEMINI_API_KEY="your-gemini-key"
export XAI_API_KEY="your-xai-key"
```

Add these to your `~/.bashrc`, `~/.zshrc`, or equivalent for persistence.

### Windows

```cmd
setx OPENAI_API_KEY "your-openai-key"
setx GEMINI_API_KEY "your-gemini-key"
setx XAI_API_KEY "your-xai-key"
```

Or set them through System Properties > Environment Variables.

## Usage

### Running the Server

```bash
# macOS / Linux
./imago_mcp_server.rb

# Windows
ruby imago_mcp_server.rb
```

### MCP Client Configuration

Add the server to your MCP client configuration. For example, in Claude Desktop's config:

#### macOS / Linux

```json
{
  "mcpServers": {
    "imago": {
      "command": "/path/to/imago-mcp/imago_mcp_server.rb"
    }
  }
}
```

#### Windows

```json
{
  "mcpServers": {
    "imago": {
      "command": "ruby",
      "args": ["C:\\path\\to\\imago-mcp\\imago_mcp_server.rb"]
    }
  }
}
```

## Available Tools

### generate_image

Generate images from a text prompt, optionally with input images for editing.

**Parameters:**
- `provider` (required): `openai`, `gemini`, or `xai`
- `prompt` (required): Text description of the image to generate
- `model`: Specific model to use (optional)
- `n`: Number of images to generate (1-10)
- `size`: Image size (OpenAI only)
- `quality`: `standard` or `hd` (OpenAI only)
- `aspect_ratio`: e.g., `16:9` (Gemini only)
- `negative_prompt`: Terms to exclude (Gemini only)
- `seed`: For reproducibility (Gemini only)
- `response_format`: `url` or `b64_json` (OpenAI/xAI)
- `images`: Array of input images for editing (OpenAI/Gemini only)

**Image Input Formats:**

The `images` parameter accepts an array where each item can be:

1. **URL string** (MIME type auto-detected from extension):
   ```json
   ["https://example.com/photo.jpg"]
   ```

2. **URL with explicit MIME type**:
   ```json
   [{"url": "https://example.com/photo", "mime_type": "image/jpeg"}]
   ```

3. **Base64-encoded data**:
   ```json
   [{"base64": "iVBORw0KGgo...", "mime_type": "image/png"}]
   ```

4. **Mixed formats** are supported in the same request.

**Provider Image Limits:**

| Provider | Image Support | Max Images |
|----------|---------------|------------|
| OpenAI   | Yes (gpt-image-*, dall-e-2) | 16 |
| Gemini   | Yes | 10 |
| xAI      | No | N/A |

Note: DALL-E 3 does not support image inputs.

### list_models

List available models for a provider.

**Parameters:**
- `provider` (required): `openai`, `gemini`, or `xai`

### list_providers

List all supported providers. No parameters required.

## Development

### Running Tests

```bash
bundle exec rspec
```

### Linting

```bash
bundle exec rubocop
```

To auto-fix offenses:

```bash
bundle exec rubocop -a
```

## License

MIT License. See [LICENSE](LICENSE) for details.
