defmodule QuizirWeb.FlashComponentTest do
  use QuizirWeb.ConnCase, async: true
  import Phoenix.Component
  import Phoenix.LiveViewTest
  import QuizirWeb.CoreComponents

  describe "flash/1 component" do
    test "renders flash centered at the top of the screen" do
      assigns = %{flash: %{"info" => "Opération réussie !"}, kind: :info}

      html =
        rendered_to_string(~H"""
        <.flash kind={@kind} flash={@flash} />
        """)

      assert html =~ "toast-center"
      assert html =~ "top-5"
      assert html =~ "left-1/2"
      assert html =~ "-translate-x-1/2"
      assert html =~ "Opération réussie !"
    end

    test "renders with 5-second auto-dismiss and progress bar by default" do
      assigns = %{flash: %{"info" => "Sauvegardé avec succès !"}, kind: :info}

      html =
        rendered_to_string(~H"""
        <.flash kind={@kind} flash={@flash} />
        """)

      assert html =~ ~s(phx-hook="FlashAutoDismiss")
      assert html =~ ~s(data-auto-dismiss="5000")
      assert html =~ "toast-progress-bar"
    end

    test "supports disabling auto-dismiss" do
      assigns = %{flash: %{"error" => "Erreur critique"}, kind: :error}

      html =
        rendered_to_string(~H"""
        <.flash kind={@kind} flash={@flash} auto_dismiss={false} />
        """)

      refute html =~ ~s(phx-hook="FlashAutoDismiss")
      refute html =~ ~s(data-auto-dismiss)
      refute html =~ "toast-progress-bar"
      assert html =~ "Erreur critique"
    end
  end
end
