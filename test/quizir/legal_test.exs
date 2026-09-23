defmodule Quizir.LegalTest do
  use Quizir.DataCase, async: true

  alias Quizir.Legal
  alias Quizir.Legal.Markdown

  describe "Legal context" do
    test "list_pages/0 returns all defined legal pages" do
      pages = Legal.list_pages()
      slugs = Enum.map(pages, & &1.slug)

      assert length(pages) == 3
      assert "mentions-legales" in slugs
      assert "cgu" in slugs
      assert "rgpd" in slugs
    end

    test "get_page/1 returns mentions légales document with required context" do
      assert {:ok, page} = Legal.get_page("mentions-legales")
      assert page.slug == "mentions-legales"
      assert page.title == "Mentions Légales"
      assert page.content_html =~ "Mentions Légales"

      # Explicit requirement: platform is for demonstrative purpose of developer skills
      assert page.content_html =~ "démonstration technique"
      assert page.content_html =~ "compétences"

      # Explicit requirement: no user information transferred to third parties
      assert page.content_html =~ "tiers"
      assert page.content_html =~ "Aucun transfert de données"
    end

    test "get_page/1 returns CGU document with required context" do
      assert {:ok, page} = Legal.get_page("cgu")
      assert page.slug == "cgu"
      assert page.title == "Conditions Générales d'Utilisation"
      assert page.content_html =~ "Conditions Générales d'Utilisation"

      # Explicit requirement: platform is for demonstrative purpose of developer skills
      assert page.content_html =~ "démonstration technique"
      assert page.content_html =~ "compétences"

      # Explicit requirement: no user information transferred to third parties
      assert page.content_html =~ "tiers"
      assert page.content_html =~ "Aucune transmission à des tiers"
    end

    test "get_page/1 returns RGPD document with required context" do
      assert {:ok, page} = Legal.get_page("rgpd")
      assert page.slug == "rgpd"
      assert page.title == "Protection des Données & RGPD"
      assert page.content_html =~ "Politique de Confidentialité"

      # Explicit requirement: platform is for demonstrative purpose of developer skills
      assert page.content_html =~ "démonstration technique"
      assert page.content_html =~ "compétences"

      # Explicit requirement: no user information transferred to third parties
      assert page.content_html =~ "tiers"
      assert page.content_html =~ "Aucune donnée personnelle"
    end

    test "get_page/1 normalizes slugs properly" do
      assert {:ok, page1} = Legal.get_page("mentions_legales")
      assert page1.slug == "mentions-legales"

      assert {:ok, page2} = Legal.get_page("tos")
      assert page2.slug == "cgu"

      assert {:ok, page3} = Legal.get_page("privacy")
      assert page3.slug == "rgpd"

      assert {:ok, page4} = Legal.get_page(:cgu)
      assert page4.slug == "cgu"
    end

    test "get_page/1 returns error for non-existent slug" do
      assert {:error, :not_found} = Legal.get_page("non-existant-slug")
    end

    test "get_page!/1 returns page or raises" do
      page = Legal.get_page!("mentions-legales")
      assert page.slug == "mentions-legales"

      assert_raise RuntimeError, ~r/Page légale introuvable/, fn ->
        Legal.get_page!("inconnu")
      end
    end
  end

  describe "Markdown parser" do
    test "parses headings, paragraphs, lists, blockquotes and inline elements" do
      input = """
      # Titre Principal
      ## Sous Titre
      ### Niveau 3

      Voici un paragraphe avec du **gras**, de l'*italique*, du `code inline` et un [lien](/test).

      ---

      > Ceci est une citation importante.

      - Premier point
      - Second point

      1. Étape une
      2. Étape deux
      """

      html = Markdown.to_html(input)

      assert html =~ "<h1"
      assert html =~ "Titre Principal"
      assert html =~ "<h2"
      assert html =~ "Sous Titre"
      assert html =~ "<h3"
      assert html =~ "Niveau 3"
      assert html =~ "<p"
      assert html =~ "<strong class=\"font-bold text-base-content\">gras</strong>"
      assert html =~ "<em class=\"italic text-base-content/90\">italique</em>"
      assert html =~ "<code class=\"font-mono"
      assert html =~ "code inline</code>"
      assert html =~ "<a href=\"/test\""
      assert html =~ "lien</a>"
      assert html =~ "<div class=\"divider"
      assert html =~ "<blockquote"
      assert html =~ "citation importante"
      assert html =~ "<ul"
      assert html =~ "Premier point"
      assert html =~ "<ol"
      assert html =~ "Étape une"
    end

    test "escapes raw HTML tags for security" do
      input = "<script>alert('xss')</script>"
      html = Markdown.to_html(input)

      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
    end

    test "handles nil and empty strings safely" do
      assert Markdown.to_html(nil) == ""
      assert Markdown.to_html("") == ""
      assert Markdown.to_html("   \n\n  ") == ""
    end
  end
end
