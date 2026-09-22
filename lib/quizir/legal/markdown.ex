defmodule Quizir.Legal.Markdown do
  @moduledoc """
  Léger parseur Markdown autonome en pur Elixir, adapté pour formater
  les documents légaux avec les classes graphiques Tailwind et DaisyUI.
  """

  @doc """
  Convertit une chaîne au format Markdown en fragment HTML sécurisé et stylisé.
  """
  @spec to_html(String.t()) :: String.t()
  def to_html(nil), do: ""

  def to_html(markdown) when is_binary(markdown) do
    markdown
    |> String.split(~r/\r?\n/)
    |> parse_blocks([])
    |> Enum.map(&render_block/1)
    |> Enum.join("\n")
  end

  defp parse_blocks([], acc), do: Enum.reverse(acc)

  defp parse_blocks([line | rest], acc) do
    trimmed = String.trim(line)

    cond do
      trimmed == "" ->
        parse_blocks(rest, acc)

      String.starts_with?(trimmed, "#### ") ->
        heading = String.replace_prefix(trimmed, "#### ", "")
        parse_blocks(rest, [{:h4, heading} | acc])

      String.starts_with?(trimmed, "### ") ->
        heading = String.replace_prefix(trimmed, "### ", "")
        parse_blocks(rest, [{:h3, heading} | acc])

      String.starts_with?(trimmed, "## ") ->
        heading = String.replace_prefix(trimmed, "## ", "")
        parse_blocks(rest, [{:h2, heading} | acc])

      String.starts_with?(trimmed, "# ") ->
        heading = String.replace_prefix(trimmed, "# ", "")
        parse_blocks(rest, [{:h1, heading} | acc])

      trimmed in ["---", "----", "***", "___"] ->
        parse_blocks(rest, [{:hr} | acc])

      String.starts_with?(trimmed, ">") ->
        {quote_lines, remaining} =
          Enum.split_while([line | rest], fn l ->
            t = String.trim(l)
            String.starts_with?(t, ">")
          end)

        cleaned_text =
          quote_lines
          |> Enum.map(fn l ->
            l
            |> String.trim()
            |> String.replace_prefix(">", "")
            |> String.trim_leading()
          end)
          |> Enum.join(" ")

        parse_blocks(remaining, [{:blockquote, cleaned_text} | acc])

      list_item?(trimmed) ->
        {list_lines, remaining} =
          Enum.split_while([line | rest], fn l ->
            t = String.trim(l)
            list_item?(t)
          end)

        type = if String.match?(String.trim(hd(list_lines)), ~r/^\d+\.\s+/), do: :ol, else: :ul

        items =
          Enum.map(list_lines, fn l ->
            t = String.trim(l)

            cond do
              String.starts_with?(t, "- ") -> String.replace_prefix(t, "- ", "")
              String.starts_with?(t, "* ") -> String.replace_prefix(t, "* ", "")
              true -> Regex.replace(~r/^\d+\.\s+/, t, "")
            end
          end)

        parse_blocks(remaining, [{type, items} | acc])

      true ->
        {p_lines, remaining} =
          Enum.split_while([line | rest], fn l ->
            t = String.trim(l)

            t != "" and not String.starts_with?(t, "#") and
              t not in ["---", "----", "***", "___"] and
              not String.starts_with?(t, ">") and not list_item?(t)
          end)

        paragraph = Enum.map(p_lines, &String.trim/1) |> Enum.join(" ")
        parse_blocks(remaining, [{:p, paragraph} | acc])
    end
  end

  defp list_item?(line) do
    String.starts_with?(line, "- ") or
      String.starts_with?(line, "* ") or
      String.match?(line, ~r/^\d+\.\s+/)
  end

  defp render_block({:h1, text}) do
    "<h1 class=\"text-2xl sm:text-3xl lg:text-4xl font-black text-base-content tracking-tight mb-6 pb-4 border-b border-base-300 flex items-center gap-3\">#{render_inline(text)}</h1>"
  end

  defp render_block({:h2, text}) do
    "<h2 class=\"text-lg sm:text-xl lg:text-2xl font-bold text-base-content mt-8 mb-3 pb-2 border-b border-base-200/60 flex items-center gap-2\">#{render_inline(text)}</h2>"
  end

  defp render_block({:h3, text}) do
    "<h3 class=\"text-base sm:text-lg font-bold text-base-content/90 mt-6 mb-2\">#{render_inline(text)}</h3>"
  end

  defp render_block({:h4, text}) do
    "<h4 class=\"text-sm sm:text-base font-semibold text-base-content/80 mt-4 mb-1.5\">#{render_inline(text)}</h4>"
  end

  defp render_block({:hr}) do
    "<div class=\"divider my-6 opacity-60\"></div>"
  end

  defp render_block({:blockquote, text}) do
    "<blockquote class=\"border-l-4 border-primary bg-primary/5 px-4 py-3 rounded-r-xl text-base-content/90 italic my-4 leading-relaxed shadow-xs\">#{render_inline(text)}</blockquote>"
  end

  defp render_block({:ul, items}) do
    lis =
      items
      |> Enum.map(fn item ->
        "<li class=\"flex items-start gap-2.5 leading-relaxed\"><span class=\"text-primary font-bold mt-0.5 select-none text-base\">•</span><span class=\"flex-1\">#{render_inline(item)}</span></li>"
      end)
      |> Enum.join("\n")

    "<ul class=\"space-y-2.5 my-4 text-base-content/80 pl-1\">\n#{lis}\n</ul>"
  end

  defp render_block({:ol, items}) do
    lis =
      items
      |> Enum.with_index(1)
      |> Enum.map(fn {item, idx} ->
        "<li class=\"flex items-start gap-2.5 leading-relaxed\"><span class=\"badge badge-sm badge-neutral font-mono font-bold mt-0.5 shrink-0\">#{idx}</span><span class=\"flex-1\">#{render_inline(item)}</span></li>"
      end)
      |> Enum.join("\n")

    "<ol class=\"space-y-2.5 my-4 text-base-content/80 pl-1\">\n#{lis}\n</ol>"
  end

  defp render_block({:p, text}) do
    "<p class=\"text-base-content/80 leading-relaxed mb-4 text-sm sm:text-base\">#{render_inline(text)}</p>"
  end

  @doc """
  Convertit les balises inline (code, liens, gras, italique) en HTML.
  """
  @spec render_inline(String.t()) :: String.t()
  def render_inline(text) do
    text
    |> escape_html()
    |> render_code()
    |> render_links()
    |> render_bold()
    |> render_italic()
  end

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp render_code(text) do
    Regex.replace(
      ~r/`([^`]+)`/,
      text,
      "<code class=\"font-mono text-xs sm:text-sm bg-base-200 text-primary px-1.5 py-0.5 rounded font-medium\">\\1</code>"
    )
  end

  defp render_links(text) do
    Regex.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, text, fn _match, label, url ->
      safe_url = if String.match?(url, ~r/^(\/|#|https?:\/\/|mailto:)/), do: url, else: "#"

      "<a href=\"#{safe_url}\" class=\"link link-primary font-semibold hover:underline underline-offset-2 transition-colors\">#{label}</a>"
    end)
  end

  defp render_bold(text) do
    Regex.replace(
      ~r/\*\*([^*]+)\*\*/,
      text,
      "<strong class=\"font-bold text-base-content\">\\1</strong>"
    )
  end

  defp render_italic(text) do
    Regex.replace(
      ~r/\*([^*]+)\*/,
      text,
      "<em class=\"italic text-base-content/90\">\\1</em>"
    )
  end
end
