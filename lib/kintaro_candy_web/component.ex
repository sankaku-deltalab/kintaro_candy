defmodule KinWeb.LiveView.Component do
  use Phoenix.Component
  # import KinWeb.CoreComponents

  attr :title, :string, default: nil
  attr :form_id, :string, required: true
  attr :form, Phoenix.HTML.Form, required: true
  attr :loading, :boolean, default: false
  attr :body_class, :string, default: ""
  attr :phx_change, :any, default: nil
  attr :phx_submit, :any, default: nil
  attr :phx_target, :any, required: true

  slot :pre_form
  slot :form_block
  slot :loading_button_block
  slot :submit_button_block

  def step_element(assigns) do
    ~H"""
    <div class="card bg-zinc-200 border m-5 shadow-xl">
      <div class={["card-body", @body_class]}>
        <h2 :if={@title} class="card-title"><%= @title %></h2>
        <%= render_slot(@pre_form) %>

        <.form
          :let={f}
          id={@form_id}
          for={@form}
          phx-change={@phx_change}
          phx-submit={@phx_submit}
          phx-target={@phx_target}
        >
          <%= render_slot(@form_block, f) %>
        </.form>

        <div class={["card-actions justify-end", "m-2"]}>
          <button :if={@loading} disabled class={["btn btn-disabled"]} form={@form_id}>
            <%= render_slot(@loading_button_block) %>
          </button>
          <button :if={not @loading} class={["btn btn-primary"]} form={@form_id}>
            <%= render_slot(@submit_button_block) %>
          </button>
        </div>
      </div>
    </div>
    """
  end
end
