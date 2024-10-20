if Code.ensure_loaded?(Bonfire.UI.Common.Web.Native) and Code.ensure_loaded?(Bonfire.UI.Common.CoreComponents.SwiftUI) do
  defmodule Bonfire.UI.Common.SharedComponents.SwiftUI do
    use Bonfire.UI.Common.Web.Native, :core
    use Bonfire.UI.Common

    # import LiveViewNative.LiveForm.Component
    # import LiveViewNative.SwiftUI.Component

    import Bonfire.UI.Common.CoreComponents.SwiftUI

    attr :style, :any
    attr :show_search, :boolean, default: false
    attr :page_title, :string, default: ""
    slot :toolbar_trailing
    slot :navigation_menu
    slot :header_menu

    def main_header(assigns) do
      ~LVN"""
      <VStack style={@style}>
        <Text template="title"> <%= @page_title %></Text>
        <ToolbarItemGroup template="toolbar" placement="navigationBarTrailing">
          <%= render_slot(@toolbar_trailing) %>
        </ToolbarItemGroup>
        <ToolbarItemGroup template="toolbar" placement="navigation">
            <%= render_slot(@navigation_menu) %>
        </ToolbarItemGroup>
        <VStack template="content">
          <%= render_slot(@header_menu) %>
        </VStack>
          <!-- Group :if={@show_search} style='searchable(text: attr("query"))' query={""} phx-change="query-changed" / -->
      </VStack>
      """
    end

    def user_preview(assigns) do
      ~LVN"""
        <HStack alignment="top">
          <!-- .image url={"https://images.squarespace-cdn.com/content/v1/5cad42ef90f904e520359371/1560899285008-UBUGYDVWRQT6CX1K9IAY/ursula.jpg"}>
            <:success style={[
              "resizable();
              frame(width: 32, height: 32);
              clipShape(.circle);
              aspectRatio(1.777, contentMode: .fill);"]}  />
          </.image-->
          <Image name="Uklg" style={[
            "resizable()",
            "frame(width: 32, height: 32)",
            "clipShape(.circle)",
            "aspectRatio(1, contentMode: .fill)"
          ]} />

          <VStack alignment="leading" style="padding(.leading, 0); padding(.top, 4);">
            <Text style="font(.footnote); fontWeight(.bold)">Ursula K. Le Guin</Text>
            <Text style="font(.footnote); foregroundStyle(.gray)">@ursulakleguin@annares.social</Text>
            <Text style="font(.footnote);">“Don’t eeeeee your philosophy. Embody it.” (Epictetus)</Text>
          </VStack>
            <Spacer/>
          <.button style="controlSize(.small); buttonStyle(.bordered);">Follow</.button>
        </HStack>

      """
    end

    def activity(%{type: "mention"} = assigns) do
      ~LVN"""
      <VStack alignment="leading" style="padding(12); padding(.bottom, 0);">
          <.activity_subject type="mention"/>
          <VStack alignment="leading" style="padding(.leading, 52); offset(y: -28); padding(.bottom, -28);">
            <.activity_object />
            <.activity_actions />
          </VStack>
      </VStack>
      """
    end

    def activity(assigns) do
      ~LVN"""
      <VStack alignment="leading" style="padding(12); padding(.bottom, 0);">
          <.activity_subject />
          <VStack alignment="leading" style="padding(.leading, 52); offset(y: -28); padding(.bottom, -28);">
            <.activity_object />
            <.activity_actions />
          </VStack>
      </VStack>
      """
    end

    def activity_subject(%{type: "mention"} = assigns) do
      ~LVN"""
      <HStack alignment="top">
      <ZStack alignment="topTrailing">

      <.link navigate={~p"/profile"}>
        <!--.image
        style={[
          "resizable();
          frame(width: 40, height: 40);
          clipShape(.circle);
          aspectRatio(1.777, contentMode: .fill);"]}
          url={~p"/assets/images/uklg.jpg"}>
           <:success style={[
            "resizable();
            frame(width: 40, height: 40);
            clipShape(.circle);
            aspectRatio(1.777, contentMode: .fill);"]}  />
        </.image -->
      <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
      </.link>
      <ZStack alignment="center" style="offset(y: -4, x: 8);">
          <Circle style="fill(Color.indigo); frame(width: 20, height: 20);" />
          <.icon
            name="at"
            style="
              font(.caption2);
              foregroundStyle(.white);
            "
          />
          </ZStack>
      </ZStack>
        <HStack style="padding(.leading, 4);">
          <.link style="" navigate={~p"/profile"}>
            <Text style="font(.callout); fontWeight(.semibold)">Ursula K. Le Guin</Text>
          </.link>
          <Spacer/>
          <HStack>
            <Text style="font(.footnote); foregroundStyle(.gray)">5 min</Text>
            <.more />
          </HStack>
        </HStack>
      </HStack>
      """
    end

    def activity_subject(assigns) do
      ~LVN"""
      <HStack alignment="top">
      <.link navigate={~p"/profile"}>
        <!--.image
        style={[
          "resizable();
          frame(width: 40, height: 40);
          clipShape(.circle);
          aspectRatio(1.777, contentMode: .fill);"]}
          url={~p"/assets/images/uklg.jpg"}>
           <:success style={[
            "resizable();
            frame(width: 40, height: 40);
            clipShape(.circle);
            aspectRatio(1.777, contentMode: .fill);"]}  />
        </.image>
      </.link -->
        <Image name="Uklg" style={[
          "resizable()",
          "frame(width: 40, height: 40)",
          "clipShape(.circle)",
          "aspectRatio(1, contentMode: .fill)"
        ]} />
        </.link>
        <HStack style="padding(.leading, 4);">
          <.link style="foregroundStyle(.white);" navigate={~p"/profile"}>
            <Text style=" font(.callout); fontWeight(.semibold)">Ursula K. Le Guin</Text>
          </.link>
          <Spacer/>
          <HStack>
            <Text style="font(.footnote); foregroundStyle(.gray)">5 min</Text>
            <.more />
          </HStack>
        </HStack>
      </HStack>
      """
    end

    def activity_object(assigns) do
      ~LVN"""
      <VStack style="padding(.top, 4);">
      <Text style="font(.callout);">Quelli ipsum dolor sit amet, consectetur adipiscing elit. Donec pulvinar, felis sit amet pulvinar sagittis, quam felis malesuada neque, accumsan rutrum velit quam id arcu.</Text>
      </VStack>
      """
    end

    def activity_media(assigns) do
      ~LVN"""
      <VStack>
        <Text>Media</Text>
      </VStack>
      """
    end

    def activity_actions(assigns) do
      ~LVN"""
      <HStack style="padding(.top, 8);">
        <Button style="buttonStyle(.plain);">
          <Label systemImage="message" style="foregroundStyle(.gray)" />
        </Button>
        <Spacer/>
        <Button style="buttonStyle(.plain);">
          <Label style="foregroundStyle(.gray)" systemImage="arrow.trianglehead.2.clockwise.rotate.90" />
        </Button>
        <Spacer/>
        <Button style="buttonStyle(.plain);">
          <Label style="foregroundStyle(.gray)" systemImage="flame" />
        </Button>
        <Spacer/>
        <Button style="buttonStyle(.plain);">
          <Label style="foregroundStyle(.gray)" systemImage="bookmark" />
        </Button>
        <Spacer/>
        <.moderation_button />
      </HStack>
      """
    end

    def moderation_button(assigns) do
      ~LVN"""
      <Menu style="padding(.leading, 4);">
        <HStack template={:label}>
        <.icon name="hand.raised" style="foregroundStyle(.gray)" />
        </HStack>
        <Group template={:content}>
          <Button>
              <Label systemImage="flag">Flag the activity</Label>
          </Button>
          <Button>
              <Label systemImage="flag">Flag the user</Label>
          </Button>
          <Divider/>
          <Button style="tint(.red);">
            <Label systemImage="exclamationmark.octagon.fill">Block user</Label>
          </Button>
        </Group>
      </Menu>
      """
    end

    def more(assigns) do
      ~LVN"""
      <Menu style="padding(.leading, 4);">
        <HStack template={:label}>
          <.icon name="ellipsis" style="foregroundStyle(.gray)" />
        </HStack>
        <Group template={:content}>
          <Button>
              <Label systemImage="globe">Public</Label>
          </Button>
          <Button>
            <Label systemImage="square.on.square">Copy link</Label>
          </Button>
          <Button>
            <Label systemImage="circle.hexagonpath">Add to circle</Label>
          </Button>
        </Group>
      </Menu>
      """
    end

    def activity_notification(%{type: "like"} = assigns) do
      ~LVN"""
      <VStack alignment="leading" style="padding(12); frame(maxWidth: .infinity);">
        <HStack alignment="top">
          <ZStack alignment="center">
            <Circle style="fill(Color.yellow); frame(width: 24, height: 24);" />
            <.icon
              name="flame.fill"
              style="
                font(.footnote);
                foregroundStyle(.white);
              "
            />
          </ZStack>
          <VStack alignment="leading" style="padding(.leading, 4);">
            <HStack alignment="leading">
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
            </HStack>
            <HStack>
            <Text style="font(.subheadline);"><Text style="fontWeight(.semibold);">Ursula K. Le Guin</Text>, and 4 more users, liked your activity</Text>
            </HStack>
            <Text style="font(.subheadline); padding(.top, 2); foregroundStyle(.gray)">Quelli ipsum dolor sit amet, consectetur adipiscing elit. Donec pulvinar, felis sit amet pulvinar sagittis, quam felis malesuada neque, accumsan rutrum velit quam id arcu.</Text>
          </VStack>
          <Spacer/>
        </HStack>
      </VStack>
      """
    end

    def activity_notification(%{type: "boost"} = assigns) do
      ~LVN"""
      <VStack alignment="leading" style="padding(12); frame(maxWidth: .infinity);">

        <HStack alignment="top">
          <ZStack alignment="center">
            <Circle style="fill(Color.green); frame(width: 24, height: 24);" />
            <.icon
              name="arrow.trianglehead.2.clockwise.rotate.90"
              style="
                font(.footnote);
                foregroundStyle(.white);
              "
            />
          </ZStack>
          <VStack alignment="leading" style="padding(.leading, 4);">
            <HStack alignment="leading">
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
            </HStack>
            <HStack>
            <Text style="font(.subheadline);"><Text style="fontWeight(.semibold);">Ursula K. Le Guin</Text>, and 4 more users, boosted your activity</Text>
            </HStack>
            <Text style="font(.subheadline); padding(.top, 2); foregroundStyle(.gray)">Quelli ipsum dolor sit amet, consectetur adipiscing elit. Donec pulvinar, felis sit amet pulvinar sagittis, quam felis malesuada neque, accumsan rutrum velit quam id arcu.</Text>
          </VStack>
          <Spacer/>
        </HStack>
      </VStack>
      """
    end

    def activity_notification(assigns) do
      ~LVN"""
      <VStack alignment="leading" style="padding(12); frame(maxWidth: .infinity);">
        <HStack alignment="top">
          <ZStack alignment="center">
          <Circle style="fill(Color.blue); frame(width: 24, height: 24);" />
          <.icon
            name="person.fill.badge.plus"
            style="
              font(.footnote);
              foregroundStyle(.white);
            "
          />
          </ZStack>
          <VStack alignment="leading" style="padding(.leading, 4);">
            <HStack alignment="leading">
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
               <Image name="Uklg" style={[
        "resizable()",
        "frame(width: 40, height: 40)",
        "clipShape(.circle)",
        "aspectRatio(1, contentMode: .fill)"
      ]} />
            </HStack>
            <HStack>
            <Text style="font(.subheadline);"><Text style="fontWeight(.semibold);">Ursula K. Le Guin</Text>, and 4 more users, followed you</Text>
          </HStack>
          <Text style="font(.subheadline); padding(.top, 2); foregroundStyle(.gray)">lara_sel@bonfire.cafe</Text>
          </VStack>
          <Spacer/>
        </HStack>
      </VStack>
      """
    end

    attr :rest, :global, include: ~w(phx-change selection)
    slot :inner_block, required: true

    def tab_bar(assigns) do
      ~LVN"""
      <TabView {@rest}>
        <%= render_slot(@inner_block) %>
      </TabView>
      """
    end

    attr :tag, :any, required: true
    attr :name, :string, required: true
    attr :icon_system_name, :string, required: true
    slot :inner_block, required: true

    def tab(assigns) do
      ~LVN"""
      <Group tag={@tag} style="tabItem(:tab);">
        <Image template={:tab} systemName={@icon_system_name} />
        <Text template={:tab}><%= @name %></Text>
        <%= render_slot(@inner_block) %>
      </Group>
      """
    end

    attr :rest, :global

    slot :option do
      attr :navigate, :string
      attr :on_click, :string
      attr :system_image, :string
      attr :role, :atom, values: [:destructive]
    end

    slot :inner_block, required: true

    def user_options(assigns) do
      ~LVN"""
      <Menu {@rest}>
        <Group template="label">
          <%= render_slot(@inner_block) %>
        </Group>
        <%= for option <- @option do %>
          <%= cond do %>
          <% navigate = option[:navigate] -> %>
            <.link navigate={navigate}>
              <Label systemImage={option[:system_image]}>
                <%= render_slot(option) %>
              </Label>
            </.link>
          <% on_click = option[:on_click] -> %>
            <.button phx-click={on_click} role={option[:role]}>
              <Label systemImage={option[:system_image]}>
                <%= render_slot(option) %>
              </Label>
            </.button>
          <% end %>
        <% end %>
      </Menu>
      """
    end

    attr :rest, :global, include: ~w(selection)
    slot :inner_block, required: true

    def workspace_list(assigns) do
      ~LVN"""
      <List {@rest}>
        <%= render_slot(@inner_block) %>
      </List>
      """
    end

    attr :title, :string, required: true
    slot :footer, default: []
    slot :inner_block, required: true

    def workspace_section(assigns) do
      ~LVN"""
      <Section>
        <Text template="header">
          <%= @title %>
        </Text>
        <Text :if={@footer != []} template="footer">
          <%= render_slot(@footer) %>
        </Text>
        <%= render_slot(@inner_block) %>
      </Section>
      """
    end

    attr :name, :string, required: true
    attr :active, :boolean, default: false
    attr :unread_count, :integer, default: 0
    attr :target, :string, default: "ios"
    attr :rest, :global, include: ~w(navigate id)
    slot :menu_items

    def channel_item(%{target: "macos"} = assigns) do
      ~LVN"""
      <Group style='contextMenu(menuItems: :menu_items);'>
        <LabeledContent {@rest} style='badge(attr("count"))' count={@unread_count}>
          <Text template="label"># <%= @name %></Text>
        </LabeledContent>
        <Group template="menu_items">
          <%= render_slot(@menu_items) %>
        </Group>
      </Group>
      """
    end

    def channel_item(assigns) do
      ~LVN"""
      <Group style='contextMenu(menuItems: :menu_items);'>
        <.link {@rest}>
          <LabeledContent style='badge(attr("count"))' count={@unread_count}>
            <Text template="label"># <%= @name %></Text>
          </LabeledContent>
        </.link>
        <Group template="menu_items">
          <%= render_slot(@menu_items) %>
        </Group>
      </Group>
      """
    end

    def navigation_menu(assigns) do
      ~LVN"""
      <.user_options>
        <:option navigate={~p"/users/sign-out"} system_image="arrow.up.backward.square">
          Sign out
        </:option>
        <:option on_click="swiftui_unregister_apns" system_image="bell.badge.slash">
          Disable notifications
        </:option>
        <:option on_click="delete_user" system_image="person.fill.xmark" role={:destructive}>
          Delete account
        </:option>
        <ZStack alignment="bottomTrailing">
        <Image name="Uklg" style={[
          "resizable()",
          "frame(width: 32, height: 32)",
          "clipShape(.circle)",
          "aspectRatio(1, contentMode: .fill)"
        ]} />
          <!-- .image url={~p"/assets/images/uklg.jpg"} style="frame(width: 40, height: 40); clipShape(.circle); aspectRatio(1.777, contentMode: .fill);">
            <:success style={["
            resizable();
            frame(width: 32, height: 32);
            clipShape(.circle);
            aspectRatio(contentMode: .fill);
            "]} />
          </.image -->
        </ZStack>
      </.user_options>
      """
    end

    def search_header_menu(_assigns) do
      nil
    end

    def search_toolbar_trailing(assigns) do
      ~LVN"""
      <Button>
        <.icon name="line.3.horizontal.decrease.circle" />
      </Button>
      """
    end

    def notifications_header_menu(assigns) do
      ~LVN"""
      <.button>
          <Label systemImage="bell">All notifications</Label>
      </.button>
      <Divider/>
      <.button>
      <Label systemImage="eye">Follow</Label>
      </.button>
      <.button>
      <Label systemImage="person.2">Follow requests</Label>
      </.button>
      <.button>
      <Label systemImage="globe">Mentions</Label>
      </.button>
      <.button phx-click="show_filters">
        <Label systemImage="line.3.horizontal.decrease.circle">Boosts</Label>
      </.button>
      <.button phx-click="show_filters">
        <Label systemImage="line.3.horizontal.decrease.circle">Posts</Label>
      </.button>
      <.button phx-click="show_filters">
        <Label systemImage="line.3.horizontal.decrease.circle">Favourited</Label>
      </.button>
      <.button phx-click="show_filters">
        <Label systemImage="line.3.horizontal.decrease.circle">Polls</Label>
      </.button>
      <.button phx-click="show_filters">
        <Label systemImage="line.3.horizontal.decrease.circle">Edited posts</Label>
      </.button>
      """
    end

    def notifications_toolbar_trailing(assigns) do
      ~LVN"""
      <Button>
        <.icon name="line.3.horizontal.decrease.circle" />
      </Button>
      """
    end

    def profile_toolbar_trailing(assigns) do
      ~LVN"""
      <Button>
        <.icon name="line.3.horizontal.decrease.circle" />
      </Button>
      """
    end

    def direct_messages_toolbar_trailing(assigns) do
      ~LVN"""
      <Button>
        <.icon name="plus" />
      </Button>
      """
    end

    def home_header_menu(assigns) do
      ~LVN"""
      <.button>
          <Label systemImage="house">Home</Label>
      </.button>
        <.button>
        <Label systemImage="eye">Following</Label>
        </.button>
        <.button>
        <Label systemImage="person.2">Local</Label>
        </.button>
        <.button>
        <Label systemImage="globe">Remote</Label>
        </.button>
        <Divider/>
        <.button phx-click="show_filters">
          <Label systemImage="line.3.horizontal.decrease.circle">Filters</Label>
        </.button>
      """
    end

    def home_toolbar_trailing(assigns) do
      ~LVN"""
      <Button>
        <.icon name="gear" />
      </Button>
      """
    end

    # attr :users, :list, required: true
    # attr :selected, :boolean, default: false
    # attr :active, :boolean, default: false
    # attr :online_fun, :any, required: true
    # attr :unread_count, :integer, default: 0
    # attr :target, :string, default: "ios"
    # attr :rest, :global, include: ~w(navigate id)

    # def direct_message_item(%{target: "macos"} = assigns) do
    #   ~LVN"""
    #   <LabeledContent {@rest} style='badge(attr("count"));' count={@unread_count}>
    #       <HStack template="label">
    #         <.user_profile user={hd(@users)} online={@online_fun.(hd(@users))} size={:xs} />
    #         <Text>
    #           <%= Enum.map_join(@users, ", ", &Lax.Users.User.display_name/1) %>
    #         </Text>
    #       </HStack>
    #     </LabeledContent>
    #   """
    # end

    # def direct_message_item(assigns) do
    #   ~LVN"""
    #   <.link {@rest}>
    #     <LabeledContent style='badge(attr("count"));' count={@unread_count}>
    #       <HStack template="label">
    #         <.user_profile user={hd(@users)} online={@online_fun.(hd(@users))} size={:xs} />
    #         <Text>
    #           <%= Enum.map_join(@users, ", ", &Lax.Users.User.display_name/1) %>
    #         </Text>
    #       </HStack>
    #     </LabeledContent>
    #   </.link>
    #   """
    # end

    # attr :channel, Lax.Channels.Channel, required: true
    # attr :users_fun, :any

    # def chat_header(%{channel: %{type: :channel}} = assigns) do
    #   ~LVN"""
    #   <.header>
    #     #<%= @channel.name %>
    #   </.header>
    #   """
    # end

    # def chat_header(%{channel: %{type: :direct_message}} = assigns) do
    #   ~LVN"""
    #   <.header>
    #     @<%= Enum.map_join(@users_fun.(@channel), ", ", &Lax.Users.User.display_name/1) %>
    #   </.header>
    #   """
    # end

    # attr :animation_key, :any
    # attr :target, :string, default: "ios"
    # slot :inner_block
    # slot :bottom_bar

    # def chat(%{target: "macos"} = assigns) do
    #   ~LVN"""
    #   <ScrollView style="scrollDismissesKeyboard(.immediately); defaultScrollAnchor(.bottom); safeAreaInset(edge: .bottom, content: :bottom_bar);">
    #     <VStack
    #       alignment="leading"
    #       style='frame(maxWidth: .infinity, alignment: .leading); animation(.default, value: attr("animation_key")); padding(.top);'
    #       animation_key={@animation_key}
    #     >
    #       <%= render_slot(@inner_block) %>
    #     </VStack>
    #     <VStack spacing="0" template={:bottom_bar} style="background(.bar, in: .rect(cornerRadius: 8)); background(content: :stroke); padding();">
    #       <%= render_slot(@bottom_bar) %>
    #       <RoundedRectangle template="stroke" cornerRadius="8" style="stroke(.separator, lineWidth: 2);" />
    #     </VStack>
    #   </ScrollView>
    #   """
    # end

    # def chat(assigns) do
    #   ~LVN"""
    #   <ScrollView style="scrollDismissesKeyboard(.immediately); defaultScrollAnchor(.bottom); safeAreaInset(edge: .bottom, content: :bottom_bar);">
    #     <VStack
    #       alignment="leading"
    #       style='frame(maxWidth: .infinity, alignment: .leading); animation(.default, value: attr("animation_key"));'
    #       animation_key={@animation_key}
    #     >
    #       <%= render_slot(@inner_block) %>
    #     </VStack>
    #     <VStack spacing="0" template={:bottom_bar} style="background(.bar);">
    #       <Divider />
    #       <%= render_slot(@bottom_bar) %>
    #     </VStack>
    #   </ScrollView>
    #   """
    # end

    # attr :message_id, :string, required: true
    # attr :user, Lax.Users.User, required: true
    # attr :user_detail_patch, :string
    # attr :online, :boolean, required: true
    # attr :time, :string, required: true
    # attr :text, :string, required: true
    # attr :compact, :boolean, required: true
    # attr :on_delete, :string, default: nil
    # attr :on_report, :string, default: nil

    # def message(%{compact: true} = assigns) do
    #   ~LVN"""
    #   <Group style='padding(.horizontal, 56); padding(.bottom, 1); contextMenu(menuItems: :delete_menu);'>
    #     <Group template={:delete_menu}>
    #       <.message_hold_actions message_id={@message_id} on_delete={@on_delete} on_report={@on_report} />
    #     </Group>
    #     <HStack style='frame(maxWidth: :infinity);'>
    #       <VStack alignment="leading">
    #         <Text markdown={@text} style="textSelection(.enabled);" />
    #       </VStack>
    #       <Spacer />
    #     </HStack>
    #   </Group>
    #   """
    # end

    # def message(assigns) do
    #   ~LVN"""
    #   <Group style="padding(.horizontal); padding(.bottom, 1); contextMenu(menuItems: :delete_menu);">
    #     <Group template={:delete_menu}>
    #       <.message_hold_actions message_id={@message_id} on_delete={@on_delete} on_report={@on_report} />
    #     </Group>
    #     <HStack style='frame(maxWidth: .infinity);'>
    #       <VStack style='padding(.top, 2)'>
    #         <.user_profile user={@user} size={:md} online={@online} />
    #         <Spacer />
    #       </VStack>
    #       <VStack alignment="leading">
    #         <HStack>
    #           <Button style="buttonStyle(.plain);" phx-click="swiftui_user_detail_patch" phx-value-profile={@user_detail_patch}>
    #             <Text style="font(.headline); foregroundStyle(.primary);">
    #               <%= Lax.Users.User.display_name(@user) %>
    #             </Text>
    #           </Button>
    #           <Spacer />
    #           <Text style="font(.caption2); foregroundStyle(.secondary); padding(.top, 4);">
    #             <%= @time %>
    #           </Text>
    #         </HStack>
    #         <Text style="font(.body); textSelection(.enabled);" markdown={@text} />
    #       </VStack>
    #       <Spacer />
    #     </HStack>
    #   </Group>
    #   """
    # end

    # attr :message_id, :string, required: true
    # attr :on_delete, :string, default: nil
    # attr :on_report, :string, default: nil

    # def message_hold_actions(assigns) do
    #   ~LVN"""
    #   <Button
    #     :if={@on_delete}
    #     role="destructive"
    #     phx-click={@on_delete}
    #     phx-value-id={@message_id}
    #   >
    #     <Label systemImage="trash">
    #       Delete message
    #     </Label>
    #   </Button>
    #   <Button
    #     :if={@on_report}
    #     role="destructive"
    #     phx-click={@on_report}
    #     phx-value-id={@message_id}
    #   >
    #     <Label systemImage="flag">
    #       Report message
    #     </Label>
    #   </Button>
    #   """
    # end

    # attr :form, Phoenix.HTML.Form, required: true
    # attr :placeholder, :string, required: true
    # attr :target, :string, default: "ios"
    # attr :rest, :global, include: ~w(phx-change phx-submit phx-target)

    # def chat_form(%{target: "macos"} = assigns) do
    #   ~LVN"""
    #   <VStack alignment="trailing" style="padding(.leading); padding(.vertical, 8); padding(.trailing, 8);">
    #     <.form {@rest} for={@form}>
    #       <.input
    #         field={Map.put(@form[:text], :errors, [])}
    #         placeholder={@placeholder}
    #         style="textFieldStyle(.plain); padding(.vertical, 4);"
    #         axis="vertical"
    #       />
    #       <LiveSubmitButton
    #         style={[
    #           "buttonStyle(.borderedProminent)",
    #           ~s[disabled(attr("disabled"))]
    #         ]}
    #         after-submit="clear"
    #         disabled={not @form.source.valid?}
    #       >
    #         <Image systemName="paperplane.fill" style="padding(4);" />
    #       </LiveSubmitButton>
    #     </.form>
    #   </VStack>
    #   """
    # end

    # def chat_form(assigns) do
    #   ~LVN"""
    #   <HStack style="padding(.leading); padding(.vertical, 8); padding(.trailing, 8);">
    #     <.form {@rest} for={@form}>
    #       <.input
    #         field={Map.put(@form[:text], :errors, [])}
    #         placeholder={@placeholder}
    #       />
    #       <LiveSubmitButton
    #         style={[
    #           "buttonStyle(.borderedProminent)",
    #           "buttonBorderShape(.circle)",
    #           "controlSize(.small)",
    #           ~s[disabled(attr("disabled"))]
    #         ]}
    #         after-submit="clear"
    #         disabled={not @form.source.valid?}
    #       >
    #         <Image systemName="paperplane.fill" style="padding(4);" />
    #       </LiveSubmitButton>
    #     </.form>
    #   </HStack>
    #   """
    # end

    # def chat_signed_out_notice(assigns) do
    #   ~LVN"""
    #   <Text
    #     style={[
    #       "font(.subheadline)",
    #       "padding(.horizontal); padding(.vertical, 12);",
    #       "frame(maxWidth: .infinity)",
    #       "overlay(content: :border)",
    #       "padding(.horizontal); padding(.vertical)"
    #     ]}
    #   >
    #     <RoundedRectangle template={:border} cornerRadius={4} style="stroke(.gray);" />
    #     You are viewing this channel anonymously. Sign in to send messages.
    #   </Text>
    #   """
    # end

    # attr :user, Lax.Users.User
    # attr :online_fun, :any, required: true
    # attr :current_user, Lax.Users.User
    # slot :inner_block

    # def user_profile_sidebar(assigns) do
    #   ~LVN"""
    #   <VStack
    #     style={[
    #       ~s[inspector(isPresented: attr("is-presented"), content: :content)]
    #     ]}
    #     is-presented={@user != nil}
    #     phx-change="swiftui_user_detail_patch"
    #   >
    #     <%= render_slot(@inner_block) %>
    #     <ScrollView
    #       template="content"
    #       :if={@user}
    #       style={[
    #         ~s[tint(attr("display_color"))],
    #         ~s[navigationTitle("Profile")]
    #       ]}
    #       display_color={@user.display_color}
    #     >
    #       <VStack
    #         alignment="leading"
    #         style="padding();"
    #       >
    #         <.user_profile user={@user} online={@online_fun.(@user)} size={:xl} />
    #         <Text style="font(.title2); bold();"><%= Lax.Users.User.display_name(@user) %></Text>

    #         <LabeledContent>
    #           <Text template="label">Status</Text>
    #           <Text><%= if @online_fun.(@user), do: "Online", else: "Away" %></Text>
    #         </LabeledContent>

    #         <LabeledContent>
    #           <% local_time = DateTime.shift_zone!(DateTime.utc_now(), @user.time_zone) %>
    #           <% local_time_strftime = Calendar.strftime(local_time, "%-I:%M%P") %>
    #           <Text template="label">Timezone</Text>
    #           <Text><%= @user.time_zone %> (<%= local_time_strftime %> local)</Text>
    #         </LabeledContent>

    #         <.link
    #           :if={@current_user && @user.deleted_at == nil}
    #           navigate={~p"/new-direct-message?to_user=#{@user}"}
    #           style='buttonStyle(.borderedProminent); controlSize(.large); padding(.vertical);'
    #         >
    #           <Text style="frame(maxWidth: .infinity);">Direct message</Text>
    #         </.link>
    #       </VStack>
    #     </ScrollView>
    #   </VStack>
    #   """
    # end
  end
end
