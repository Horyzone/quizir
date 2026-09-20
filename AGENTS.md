# AGENTS.md - Quizir

Guide opérationnel, contexte métier et contraintes techniques pour les agents autonomes intervenant sur le dépôt Quizir.

---

## 1. Vue d'ensemble du projet Quizir

**Quizir** est une application web en temps réel développée en **Elixir / Phoenix** permettant de concevoir des quiz (publics ou protégés par code d'accès) et de lancer des parties multijoueurs synchronisées (lobbies, diffusion en direct des questions avec compte à rebours, soumission des réponses et classements instantanés).

### Stack technique
* **Langage :** Elixir (OTP / BEAM)
* **Framework :** Phoenix Framework v1.8+ avec Bandit[cite: 1]
* **Interface temps réel :** Phoenix LiveView v1.x (moteur de template HEEx moderne)[cite: 1]
* **Persistance :** PostgreSQL via Ecto[cite: 1]
* **Événements & Concurrence :** Phoenix PubSub / OTP primitives (`Registry`, `DynamicSupervisor`)[cite: 1]
* **Styles :** Tailwind CSS v4[cite: 1]
* **Client HTTP :** `Req` (inclus par défaut)[cite: 1]

---

## 2. Architecture des contextes et nommage

L'application suit la séparation stricte par contextes métier :

* `lib/quizir/quizzes/` :
  * `Quiz` : titre, description, visibilité (`public` / `private`).
  * `Question` : énoncé (`body`), ordre d'affichage (`order`), délai imparti en secondes (`time_limit_seconds`).
  * `AnswerOption` : texte du choix (`body`), statut de validité (`is_correct`).
  * Schémas imbriqués gérés via `cast_assoc/3`.
* `lib/quizir/games/` :
  * Moteur de partie multijoueur, gestion des salons (lobbies), sessions de jeu en cours, chronomètres et calcul des scores.
* `lib/quizir_web/live/` :
  * `QuizLive.*` : liste, création, modification et consultation des quiz.
  * `GameLive.*` : lobby d'attente, écran de question en direct, tableau des scores.
* `lib/quizir_web/components/` :
  * `layouts.ex`, `core_components.ex` (composants `<.input>`, `<.icon>`, `<.button>`).

---

## 3. Project guidelines

- Use `mix precommit` alias when you are done with all changes and fix any pending issues[cite: 1]
- Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps[cite: 1]

### Phoenix v1.8 guidelines

- **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content[cite: 1]
- The `QuizirWeb.Layouts` module is aliased in the `lib/quizir_web.ex` file, so you can use it without needing to alias it again[cite: 1]
- Anytime you run into errors with no `current_scope` assign:
  - You failed to follow the Authenticated Routes guidelines, or you failed to pass `current_scope` to `<Layouts.app>`[cite: 1]
  - **Always** fix the `current_scope` error by moving your routes to the proper `live_session` and ensure you pass `current_scope` as needed[cite: 1]
- Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module[cite: 1]
- Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar[cite: 1]
- **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors[cite: 1]
- If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your custom classes must fully style the input[cite: 1]

### JS and CSS guidelines

- **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces[cite: 1].
- Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`[cite: 1]:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/quizir_web";

- **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`[cite: 1]
- **Never** use `@apply` when writing raw css[cite: 1]
- **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design[cite: 1]
- Out of the box **only the app.js and app.css bundles are supported**[cite: 1]
  - You cannot reference an external vendor'd script `src` or link `href` in the layouts[cite: 1]
  - You must import the vendor deps into app.js and app.css to use them[cite: 1]
  - **Never write inline <script>custom js</script> tags within templates**[cite: 1]

### UI/UX & design guidelines

- **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles[cite: 1]
- Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)[cite: 1]
- Ensure **clean typography, spacing, and layout balance** for a refined, premium look[cite: 1]
- Focus on **delightful details** like hover effects, loading states, and smooth page transitions[cite: 1]

<!-- usage-rules-start -->

<!-- phoenix:elixir-start -->
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**[cite: 1]

  **Never do this (invalid)**[cite: 1]:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie[cite: 1]:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie[cite: 1]:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors[cite: 1]
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets[cite: 1]
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)[cite: 1]
- Don't use `String.to_atom/1` on user input (memory leak risk)[cite: 1]
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards[cite: 1]
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: Quizir.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(Quizir.MyDynamicSup, child_spec)`[cite: 1]
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option[cite: 1]

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)[cite: 1]
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`[cite: 1]
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason[cite: 1]

## Test guidelines

- **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests[cite: 1]
- **Avoid** `Process.sleep/1` and `Process.alive?/1` in tests[cite: 1]
  - Instead of sleeping to wait for a process to finish, **always** use `Process.monitor/1` and assert on the DOWN message[cite: 1]:

      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

   - Instead of sleeping to synchronize before the next call, **always** use `_ = :sys.get_state/1` to ensure the process has handled prior messages[cite: 1]
<!-- phoenix:elixir-end -->

<!-- phoenix:phoenix-start -->
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes[cite: 1].

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie[cite: 1]:

      scope "/quizzes", QuizirWeb do
        pipe_through :browser

        live "/", QuizLive.Index, :index
      end

  the `QuizLive.Index` route will resolve to `QuizirWeb.QuizLive.Index`[cite: 1].

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it[cite: 1]
<!-- phoenix:phoenix-end -->

<!-- phoenix:ecto-start -->
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates (e.g. `quiz.questions`, `question.answer_options`)[cite: 1]
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`[cite: 1]
- `Ecto.Schema` fields always use the `:string` type, even for `:text` columns, ie: `field :description, :string`[cite: 1]
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such an option is never needed[cite: 1]
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields[cite: 1]
- Fields which are set programmatically, such as `user_id` or ownership fields, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct[cite: 1]
- **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied[cite: 1]
<!-- phoenix:ecto-end -->

<!-- phoenix:html-start -->
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or `.html.heex` files (known as HEEx), **never** use `~E`[cite: 1]
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated[cite: 1]
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="quiz-form">`), then access those forms in the template via `@form[:field]`[cite: 1]
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="quiz-form">`)[cite: 1]
- For "app wide" template imports, import/alias into `lib/quizir_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponents, and all modules that call `use QuizirWeb, :html`[cite: 1]

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals[cite: 1].

  **Never do this (invalid)**[cite: 1]:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this[cite: 1]:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`[cite: 1]:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax[cite: 1]

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**[cite: 1]:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100")
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)[cite: 1]

  and **never** do this, since it's invalid (note the missing `[` and `]`)[cite: 1]:

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`[cite: 1]
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)[cite: 1]
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`[cite: 1].

  **Always** do this[cite: 1]:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error[cite: 1]:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>
<!-- phoenix:html-end -->

<!-- phoenix:liveview-start -->
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions in LiveViews[cite: 1]
- **Avoid LiveComponent's** unless you have a strong, specific need for them[cite: 1]
- LiveViews should be named like `QuizirWeb.QuizLive.Index`, with a `Live` suffix. When you add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `QuizirWeb` module, so you can just do `live "/quizzes", QuizLive.Index`[cite: 1]

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations[cite: 1]:
  - basic append of N items - `stream(socket, :quizzes, [new_quiz])`[cite: 1]
  - resetting stream with new items - `stream(socket, :quizzes, [new_quiz], reset: true)` (e.g. for filtering items)[cite: 1]
  - prepend to stream - `stream(socket, :quizzes, [new_quiz], at: -1)`[cite: 1]
  - deleting items - `stream_delete(socket, :quizzes, quiz)`[cite: 1]

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="quizzes"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :quizzes, [new_quiz])` in the LiveView, the template would be[cite: 1]:

      <div id="quizzes" phx-update="stream">
        <div :for={{id, quiz} <- @streams.quizzes} id={id}>
          {quiz.title}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**[cite: 1]:

      def handle_event("filter", %{"filter" => filter}, socket) do
        quizzes = list_quizzes(filter)

        {:noreply,
         socket
         |> assign(:quizzes_empty?, quizzes == [])
         |> stream(:quizzes, quizzes, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes[cite: 1]:

      <div id="quizzes" phx-update="stream">
        <div class="hidden only:block">Aucun quiz disponible pour le moment.</div>
        <div :for={{id, quiz} <- @streams.quizzes} id={id}>
          {quiz.title}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension[cite: 1].

- When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items along with the updated assign[cite: 1]:

      def handle_event("edit_question", %{"question_id" => question_id}, socket) do
        question = Quizzes.get_question!(question_id)
        edit_form = to_form(Quizzes.change_question(question, %{body: question.body}))

        {:noreply,
         socket
         |> stream_insert(:questions, question)
         |> assign(:editing_question_id, String.to_integer(question_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template[cite: 1]:

      <div id="questions" phx-update="stream">
        <div :for={{id, question} <- @streams.questions} id={id} class="flex group">
          {question.body}
          <%= if @editing_question_id == question.id do %>
            <.form for={@edit_form} id={"edit-form-#{question.id}"} phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections[cite: 1]

### LiveView JavaScript interop

- Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute[cite: 1]
- **Always** provide a unique DOM id alongside `phx-hook` otherwise a compiler error will be raised[cite: 1]

LiveView hooks come in two flavors, 1) colocated js hooks for "inline" scripts defined inside HEEx, and 2) external `phx-hook` annotations where JavaScript object literals are defined and passed to the `LiveSocket` constructor[cite: 1].

#### Inline colocated js hooks

**Never** write raw embedded `<script>` tags in heex as they are incompatible with LiveView[cite: 1].
Instead, **always use a colocated js hook script tag (`:type={Phoenix.LiveView.ColocatedHook}`) when writing scripts inside the template**[cite: 1]:

    <input type="text" name="quiz[access_code]" id="quiz-access-code" phx-hook=".AccessCodeMask" />
    <script :type={Phoenix.LiveView.ColocatedHook} name=".AccessCodeMask">
      export default {
        mounted() {
          this.el.addEventListener("input", e => {
            this.el.value = this.el.value.toUpperCase().replace(/[^A-Z0-9]/g, "")
          })
        }
      }
    </script>

- colocated hooks are automatically integrated into the app.js bundle[cite: 1]
- colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.AccessCodeMask`[cite: 1]

#### External phx-hook

External JS hooks (`<div id="buzzer" phx-hook="BuzzerSound">`) must be placed in `assets/js/` and passed to the LiveSocket constructor[cite: 1]:

    const BuzzerSound = {
      mounted() { ... }
    }
    let liveSocket = new LiveSocket("/live", Socket, {
      hooks: { BuzzerSound }
    });

#### Pushing events between client and server

Use LiveView's `push_event/3` when you need to push events/data to the client for a phx-hook to handle[cite: 1].
**Always** return or rebind the socket on `push_event/3` when pushing events[cite: 1]:

    socket = push_event(socket, "play_timer_tick", %{remaining: 5})

    def handle_event("submit_answer", _, socket) do
      {:noreply, push_event(socket, "vibrate", %{duration: 200})}
    end

Pushed events can then be picked up in a JS hook with `this.handleEvent`[cite: 1]:

    mounted() {
      this.handleEvent("play_timer_tick", data => console.log("Time left:", data.remaining));
    }

Clients can also push an event to the server and receive a reply with `this.pushEvent`[cite: 1]:

    mounted() {
      this.el.addEventListener("click", e => {
        this.pushEvent("quick_answer", { choice_id: 1 }, reply => console.log("Score update:", reply));
      })
    }

Where the server handled it via[cite: 1]:

    def handle_event("quick_answer", %{"choice_id" => choice_id}, socket) do
      {:reply, %{status: "accepted"}, socket}
    end

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions[cite: 1]
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions[cite: 1]
- Come up with a step-by-step test plan that splits major test cases into small, isolated files[cite: 1]. You may start with simpler tests that verify content exists, gradually add interaction tests[cite: 1]
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc[cite: 1]
- **Never** test against raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#quiz-form")`[cite: 1]
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements[cite: 1]
- Focus on testing outcomes rather than implementation details[cite: 1]
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected[cite: 1]. Test against the output HTML structure, not your mental model of what you expect it to be[cite: 1]
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output[cite: 1]:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params[cite: 1]:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys[cite: 1].
You can also specify a name to nest the params[cite: 1]:

    def handle_event("submitted", %{"quiz" => quiz_params}, socket) do
      {:noreply, assign(socket, form: to_form(quiz_params, as: :quiz))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it[cite: 1]. The `:as` option is automatically computed too[cite: 1]:

    %Quizir.Quizzes.Quiz{}
    |> Quizir.Quizzes.Quiz.changeset(%{})
    |> to_form()

Once the form is submitted, the params will be available under `%{"quiz" => quiz_params}`[cite: 1].

In the template, pass the form assign to the `<.form>` component[cite: 1]:

    <.form for={@form} id="quiz-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:title]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="quiz-form"`[cite: 1].

#### Nested forms with `<.inputs_for>`

Pour les questions et choix de réponses associés à un quiz, utiliser la fonction composant `inputs_for/1`[cite: 1] :

    <.inputs_for :let={q_form} field={@form[:questions]}>
      <.input field={q_form[:body]} type="text" />
      <.inputs_for :let={opt_form} field={q_form[:answer_options]}>
        <.input field={opt_form[:body]} type="text" />
      </.inputs_for>
    </.inputs_for>

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template[cite: 1]. In the template **always access forms like this**[cite: 1]:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="quiz-form">
      <.input field={@form[:title]} type="text" />
    </.form>

And **never** do this[cite: 1]:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="quiz-form">
      <.input field={@changeset[:title]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors[cite: 1]
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`[cite: 1]. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset[cite: 1].
<!-- phoenix:liveview-end -->

<!-- usage-rules-end -->