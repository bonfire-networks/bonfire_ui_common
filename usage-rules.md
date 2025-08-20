# Bonfire.UI.Common Usage Rules

Bonfire.UI.Common provides the foundational UI framework for building web interfaces in Bonfire applications. It abstracts Phoenix LiveView and Surface components, offering consistent patterns for UI development.

## Core Module Setup

Use the appropriate module template based on your component type:

```elixir
# For stateless Surface components (preferred)
use Bonfire.UI.Common.Web, :stateless_component

# For stateful Surface components  
use Bonfire.UI.Common.Web, :stateful_component

# For Phoenix function components
use Bonfire.UI.Common.Web, :html

# For Phoenix LiveViews
use Bonfire.UI.Common.Web, :controller
use Bonfire.UI.Common.Web, :view  

# For Surface LiveViews
use Bonfire.UI.Common.Web, :surface_view
```

## Component Development

### Surface Components (Preferred)

Surface components use `.sface` templates and provide better type checking:

```elixir
defmodule Bonfire.UI.MyComponent do
  use Bonfire.UI.Common.Web, :stateless_component

  prop title, :string, required: true
  prop class, :css_class, default: ""

  def render(assigns) do
    ~F"""
    <div class={"my-component", @class}>
      <h3>{@title}</h3>
      <#slot />
    </div>
    """
  end
end
```

### Using Components

Always use `maybe_component/2` to ensure components are available:

```elixir
# For stateless components
<StatelessComponent module={maybe_component(Bonfire.UI.Extension.MyComponent, @__context__)} 
  title="Hello" />

# For stateful components  
<StatefulComponent id="unique-id" 
  module={maybe_component(Bonfire.UI.Extension.MyLiveComponent, @__context__)} />


## Event Handling with LiveHandlers

Use the LiveHandler pattern for reusable event handling:

```elixir
defmodule Bonfire.UI.MyExtension.LiveHandlers do
  use Bonfire.UI.Common.Web, :live_handler

  def handle_event("my_action", %{"value" => value}, socket) do
    # Handle the event
    {:noreply, assign(socket, result: value)}
  end

  def handle_info({:my_message, data}, socket) do
    # Handle messages
    {:noreply, assign(socket, data: data)}
  end
end
```

Reference handlers with naming conventions:

```html
<button phx-click="Bonfire.UI.MyExtension:my_action">Click me</button>
```

## Styling and Theming

### Using DaisyUI Components

Use semantic DaisyUI classes for consistent styling:

```elixir
~F"""
<div class="card bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Title</h2>
    <div class="card-actions">
      <button class="btn btn-primary">Action</button>
    </div>
  </div>
</div>
"""
```

### Theme-Aware Colors

Use CSS variables for theme-aware colors:

```css
.my-component {
  color: var(--color-primary);
  background-color: var(--base-100);
}
```

### Custom Themes

Define custom themes using OKLCH color space:

```elixir
Config.put(:bonfire_ui_common, :custom_themes, [
  %{
    id: "my_theme",
    name: "My Theme",
    primary: "oklch(65.08% 0.19 238.96)",
    secondary: "oklch(74.51% 0.13 307.72)",
    # ... other colors
  }
])
```

## Localization

Always localize user-facing strings:

```elixir
# In templates
~F"""
<span>{l("Welcome back!")}</span>
<button>{l("Save changes")}</button>
"""

# In code
import Bonfire.Common.Localise
message = l("Operation completed successfully")
```

## Asset Management

### Images

Use lazy loading for images:

```elixir
<LazyImage src={@image_url} 
  alt={l("Profile picture")}
  class="w-16 h-16 rounded-full"
  loading="lazy" />
```

### Icons

Use Iconify for icons:

```elixir
<Iconify.iconify icon="heroicons:heart" class="w-5 h-5" />
<Iconify.iconify icon="carbon:bookmark" />
```

## Error Handling

### Resilient Component Loading

Use `undead_*` functions for fault tolerance:

```elixir
# Render with fallback on error
undead_render(Bonfire.UI.Extension.ComplexComponent, 
  assigns: assigns,
  fallback: ~F"<div>Component unavailable</div>"
)
```

### Error Assignment

Handle errors consistently in LiveViews:

```elixir
socket
|> assign_error(l("Failed to save changes"))
|> assign_flash(:error, l("Please try again"))
```

## Navigation and Routing

### Links

Use Surface link components:

```elixir
<LinkLive to={~p"/users/#{@user.id}"}>
  {e(@user, :profile, :name, "User")}
</LinkLive>

<LinkPatchLive to={~p"/settings?tab=profile"}>
  {l("Edit Profile")}
</LinkPatchLive>
```

### Path Generation

Use path helpers consistently:

```elixir
# In LiveView
{:noreply, push_navigate(socket, to: ~p"/dashboard")}

# With query params
{:noreply, push_patch(socket, to: ~p"/users?filter=active&page=2")}
```

## Extension Behaviors

### Creating Widgets

Implement the widget behavior:

```elixir
defmodule Bonfire.UI.MyExtension.MyWidget do
  use Bonfire.UI.Common.WidgetModule

  @impl true
  def widget_subject(), do: l("My Widget")

  @impl true  
  def widget_icon(), do: "carbon:widget"

  @impl true
  def widget_component(), do: Bonfire.UI.MyExtension.MyWidgetLive
end
```

### Smart Input Extensions

Add composer functionality:

```elixir
defmodule Bonfire.UI.MyExtension.MyComposer do
  use Bonfire.UI.Common.SmartInputModule

  @impl true
  def smart_input_component(), do: Bonfire.UI.MyExtension.ComposerLive

  @impl true
  def smart_input_opts(), do: [
    submit_label: l("Publish"),
    placeholder: l("What's on your mind?")
  ]
end
```

## Testing Components

### Unit Testing Surface Components

Test Surface components in isolation:

```elixir
use Bonfire.UI.Common.Testing.ConnCase

test "renders component", %{conn: conn} do
  html = render_surface(Bonfire.UI.MyComponent, %{
    title: "Test Title",
    __context__: %{current_user: fake_user!()}
  })

  assert html =~ "Test Title"
end
```

### Integration Testing with PhoenixTest

Use PhoenixTest for full LiveView interaction testing:

```elixir
use Bonfire.UI.Common.Testing.ConnCase
import PhoenixTest

test "user can interact with component", %{conn: conn} do
  user = fake_user!()
  
  conn
  |> login_as(user)
  |> visit(~p"/dashboard")
  |> assert_has("h1", text: "Dashboard")
  |> click_button("Open Modal")
  |> assert_has("#modal", text: "Modal Content")
  |> fill_in("Search", with: "test query")
  |> submit_form("#search-form")
  |> assert_has(".search-results", text: "Results")
end

test "live component updates dynamically", %{conn: conn} do
  user = fake_user!()
  
  conn
  |> login_as(user)
  |> visit(~p"/posts")
  |> click_link("New Post")
  |> within("#post-form", fn session ->
    session
    |> fill_in("Title", with: "My Post")
    |> fill_in("Content", with: "Post content")
    |> click_button("Publish")
  end)
  |> assert_has(".flash-info", text: "Post created successfully")
  |> assert_has(".post-title", text: "My Post")
end
```

### Testing LiveHandler Events

Test event handlers with PhoenixTest:

```elixir
test "handles custom events", %{conn: conn} do
  user = fake_user!()
  
  conn
  |> login_as(user)
  |> visit(~p"/activities")
  |> click_button("Like", nth: 1)
  |> assert_has("[data-liked=true]")
  |> refute_has(".flash-error")
  
  # Test keyboard shortcuts
  |> send_keys(["cmd+k"])
  |> assert_has("#search-modal")
  |> send_keys(["Escape"])
  |> refute_has("#search-modal")
end
```

### Testing Component Accessibility

Verify accessibility requirements:

```elixir
test "component is accessible", %{conn: conn} do
  conn
  |> visit(~p"/profile")
  |> assert_has("button[aria-label='Edit profile']")
  |> assert_has("img[alt]")
  |> assert_has("form[aria-describedby]")
  |> click_button("Edit profile")
  |> assert_has("#edit-form[role='dialog'][aria-modal='true']")
end
```

### Testing Error States

Test component error handling:

```elixir
test "handles errors gracefully", %{conn: conn} do
  # Mock an error condition
  expect(MyMock, :fetch_data, fn _ -> {:error, :not_found} end)
  
  conn
  |> visit(~p"/data")
  |> assert_has(".error-message", text: "Data not found")
  |> refute_has(".data-content")
end
```

### Testing Real-time Updates

Test Phoenix PubSub and live updates:

```elixir
test "receives real-time updates", %{conn: conn} do
  user = fake_user!()
  
  session = 
    conn
    |> login_as(user)
    |> visit(~p"/chat")
  
  # Simulate another user sending a message
  send_message_as_other_user("Hello!")
  
  session
  |> assert_has(".message", text: "Hello!", wait: true)
  |> assert_has(".message-author", text: "Other User")
end
```

## Performance Optimization

### Async Updates

Use async patterns for bulk operations:

```elixir
send_updates_after(socket.assigns.activities, 
  fn activity -> 
    send_update(ActivityLive, id: activity.id, updated: true)
  end,
  timeout: 10
)
```

### Component Keys

Use proper keys for list rendering:

```elixir
~F"""
<div :for={{id, item} <- @items} key={id}>
  <StatefulComponent id={"item-#{id}"} 
    module={maybe_component(ItemComponent, @__context__)} 
    item={item} />
</div>
"""
```

## Common Anti-Patterns to Avoid

### ❌ Direct Component References
```elixir
# Bad
<Bonfire.UI.Extension.MyComponent />

# Good
<StatelessComponent module={maybe_component(Bonfire.UI.Extension.MyComponent, @__context__)} />
```

### ❌ Hardcoded Strings
```elixir
# Bad  
<button>Save</button>

# Good
<button>{l("Save")}</button>
```

### ❌ Inline Styles
```elixir
# Bad
<div style="color: red; padding: 10px">

# Good
<div class="text-error p-4">
```

### ❌ Unhandled Errors
```elixir
# Bad
{:ok, result} = dangerous_operation()

# Good
case dangerous_operation() do
  {:ok, result} -> use_result(result)
  {:error, reason} -> assign_error(socket, reason)
end
```

## Security Considerations

- Always sanitize user input before rendering
- Use `Phoenix.HTML.raw/1` carefully and only with trusted content
- Validate all phx-event parameters
- Use CSRF tokens for forms
- Escape JavaScript in data attributes

## CSS and JavaScript

### Including JavaScript Hooks

Register hooks in your component:

```javascript
// In component.hooks.js
export default {
  mounted() {
    // Hook logic
  }
}
```

```elixir
# In component.ex
def render(assigns) do
  ~F"""
  <div id="my-hook" phx-hook="MyHook">
    Content
  </div>
  """
end
```

### CSS Organization

Follow the structure:
- Component-specific styles in `component.css`
- Global styles in `assets/css/app.css`
- Use CSS modules for scoping when needed

## Module Organization

Structure UI extensions consistently:

```
bonfire_ui_extension/
├── lib/
│   ├── components/           # Surface/LiveView components
│   ├── live_handlers.ex      # Shared event handlers
│   ├── views/               # Page-level LiveViews
│   └── runtime_config.ex     
├── assets/
│   ├── css/                 # Styles
│   └── js/                  # JavaScript hooks
└── usage-rules.md
```

## Accessibility

Follow WCAG guidelines:

```elixir
~F"""
<button aria-label={l("Close dialog")} 
  role="button"
  tabindex="0">
  <Iconify.iconify icon="carbon:close" aria-hidden="true" />
</button>
"""
```

## Documentation Standards

Document components with examples:

```elixir
@doc """
Renders a user card with avatar and name.

## Props
- `user` - User struct with profile data
- `show_status` - Whether to show online status (default: true)
- `class` - Additional CSS classes

## Examples

    <UserCard user={@current_user} show_status={false} />
"""
```