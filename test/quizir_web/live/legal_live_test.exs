defmodule QuizirWeb.LegalLiveTest do
  use QuizirWeb.ConnCase

  alias Quizir.Accounts

  describe "LegalLive Show pages" do
    test "renders Mentions Légales page via ~p'/mentions-legales'", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/mentions-legales")

      assert has_element?(view, "#legal-doc-mentions-legales")
      assert html =~ "Mentions Légales"
      assert html =~ "démonstration technique"
      assert html =~ "tiers"
    end

    test "renders CGU page via ~p'/cgu'", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/cgu")

      assert has_element?(view, "#legal-doc-cgu")
      assert html =~ "Conditions Générales d&#39;Utilisation"
      assert html =~ "démonstration technique"
      assert html =~ "tiers"
    end

    test "renders RGPD page via ~p'/rgpd'", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/rgpd")

      assert has_element?(view, "#legal-doc-rgpd")
      assert html =~ "Politique de Confidentialité"
      assert html =~ "démonstration technique"
      assert html =~ "tiers"
    end

    test "renders page via generic route ~p'/legal/mentions-legales'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/legal/mentions-legales")
      assert has_element?(view, "#legal-doc-mentions-legales")
    end

    test "redirects to mentions légales with flash when slug does not exist", %{conn: conn} do
      {:ok, _view, _html} =
        conn
        |> live(~p"/legal/document-inconnu")
        |> follow_redirect(conn, ~p"/mentions-legales")
    end

    test "tab navigation allows navigating between legal documents", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/mentions-legales")

      assert has_element?(view, "a[href='/cgu']", "Conditions Générales d'Utilisation")
      assert has_element?(view, "a[href='/rgpd']", "Protection des Données & RGPD")
    end
  end

  describe "Footer accessibility" do
    test "footer contains links to Mentions Légales, CGU and RGPD on the home page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#footer-mentions-legales-link[href='/mentions-legales']")
      assert has_element?(view, "#footer-cgu-link[href='/cgu']")
      assert has_element?(view, "#footer-rgpd-link[href='/rgpd']")
    end

    test "footer mentions demonstrative nature and no data transmission", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Démonstrateur technique"
      assert html =~ "Aucune donnée transmise à des tiers"
    end

    test "legal pages are accessible even when initial admin setup is required", %{conn: conn} do
      Application.put_env(:quizir, :force_initial_admin_setup, true)
      on_exit(fn -> Application.put_env(:quizir, :force_initial_admin_setup, false) end)

      # Ensure 0 users in DB
      if Accounts.any_users?() do
        Quizir.Repo.delete_all(Quizir.Accounts.UserToken)
        Quizir.Repo.delete_all(Quizir.Accounts.User)
      end

      # Non-legal routes redirect to register
      assert {:error, {:redirect, %{to: "/users/register"}}} = live(conn, ~p"/quizzes")

      # Legal routes are NOT redirected, they can be viewed directly
      {:ok, view, _html} = live(conn, ~p"/mentions-legales")
      assert has_element?(view, "#legal-doc-mentions-legales")

      {:ok, view_cgu, _html} = live(conn, ~p"/cgu")
      assert has_element?(view_cgu, "#legal-doc-cgu")

      {:ok, view_rgpd, _html} = live(conn, ~p"/rgpd")
      assert has_element?(view_rgpd, "#legal-doc-rgpd")
    end
  end
end
