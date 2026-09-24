defmodule Quizir.Storage do
  @moduledoc """
  Handles file uploads to S3.
  Image uploading can only be activated if an S3 configuration via environment variables is active.
  """

  require Logger

  @doc """
  Checks if S3 upload is configured via environment variables.
  """
  def s3_configured?(env_getter \\ &System.get_env/1) do
    case Application.get_env(:quizir, :s3_configured_override) do
      val when is_boolean(val) ->
        val

      _ ->
        config = get_s3_config(env_getter)
        config.bucket != nil and config.access_key_id != nil and config.secret_access_key != nil
    end
  end

  @doc """
  Uploads a file to S3.
  Returns `{:ok, url}` or `{:error, reason}`.
  Upload is strictly disabled if S3 is not configured via environment variables.
  """
  def upload_file(local_path, original_filename) do
    if s3_configured?() do
      case Application.get_env(:quizir, :storage_test_uploader) do
        fun when is_function(fun, 2) ->
          fun.(local_path, original_filename)

        _ ->
          ext = Path.extname(original_filename) |> String.downcase()
          random_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

          sanitized_name =
            Path.basename(original_filename, ext) |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")

          key = "uploads/#{random_id}_#{sanitized_name}#{ext}"
          content_type = mime_type(ext)

          upload_to_s3(local_path, key, content_type)
      end
    else
      {:error, :s3_not_configured}
    end
  end

  defp upload_to_s3(local_path, key, content_type) do
    config = get_s3_config()

    case File.read(local_path) do
      {:ok, body} ->
        sigv4_opts = [
          access_key_id: config.access_key_id,
          secret_access_key: config.secret_access_key,
          region: config.region
        ]

        sigv4_opts =
          if config.endpoint do
            Keyword.put(sigv4_opts, :endpoint_url, config.endpoint)
          else
            sigv4_opts
          end

        req_opts = [aws_sigv4: sigv4_opts]

        req_opts =
          if config.endpoint do
            Keyword.put(req_opts, :aws_endpoint_url_s3, config.endpoint)
          else
            req_opts
          end

        req = Req.new() |> ReqS3.attach(req_opts)
        s3_url = "s3://#{config.bucket}/#{key}"

        headers = [
          {"content-type", content_type}
        ]

        case Req.put(req, url: s3_url, body: body, headers: headers) do
          {:ok, %{status: status}} when status in 200..299 ->
            public_url = build_public_url(config, key)
            {:ok, public_url}

          {:ok, %{status: status, body: resp_body}} ->
            Logger.error(
              "Failed to upload file to S3: status #{status}, body: #{inspect(resp_body)}"
            )

            {:error, :upload_failed}

          {:error, reason} ->
            Logger.error("S3 upload request error: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Deletes an uploaded file from S3 if possible.
  """
  def delete_file(url) when is_binary(url) do
    cond do
      String.starts_with?(url, "/uploads/") ->
        priv_dir = :code.priv_dir(:quizir) || "priv"
        relative = String.trim_leading(url, "/")
        local_path = Path.join([priv_dir, "static", relative])
        File.rm(local_path)
        :ok

      s3_configured?() ->
        config = get_s3_config()
        # Extract key from URL
        key = extract_s3_key(url, config)

        if key do
          sigv4_opts = [
            access_key_id: config.access_key_id,
            secret_access_key: config.secret_access_key,
            region: config.region
          ]

          sigv4_opts =
            if config.endpoint do
              Keyword.put(sigv4_opts, :endpoint_url, config.endpoint)
            else
              sigv4_opts
            end

          req = Req.new() |> ReqS3.attach(aws_sigv4: sigv4_opts)
          s3_url = "s3://#{config.bucket}/#{key}"
          Req.delete(req, url: s3_url)
          :ok
        else
          :ok
        end

      true ->
        :ok
    end
  rescue
    _ -> :ok
  end

  def delete_file(_), do: :ok

  defp extract_s3_key(url, config) do
    cond do
      config.public_url && String.starts_with?(url, config.public_url) ->
        String.replace_prefix(url, String.trim_trailing(config.public_url, "/") <> "/", "")

      String.contains?(url, "/#{config.bucket}/") ->
        [_, key] = String.split(url, "/#{config.bucket}/", parts: 2)
        key

      true ->
        case URI.parse(url).path do
          nil -> nil
          path -> String.trim_leading(path, "/")
        end
    end
  end

  defp build_public_url(config, key) do
    cond do
      config.public_url ->
        "#{String.trim_trailing(config.public_url, "/")}/#{key}"

      config.endpoint ->
        endpoint = String.trim_trailing(config.endpoint, "/")
        "#{endpoint}/#{config.bucket}/#{key}"

      true ->
        "https://#{config.bucket}.s3.#{config.region}.amazonaws.com/#{key}"
    end
  end

  @doc """
  Returns the S3 configuration map resolved from environment variables.
  """
  def get_s3_config(env_getter \\ &System.get_env/1) do
    bucket = env_getter.("S3_BUCKET") || env_getter.("AWS_S3_BUCKET")
    access_key_id = env_getter.("S3_ACCESS_KEY_ID") || env_getter.("AWS_ACCESS_KEY_ID")

    secret_access_key =
      env_getter.("S3_SECRET_ACCESS_KEY") || env_getter.("AWS_SECRET_ACCESS_KEY")

    region = env_getter.("S3_REGION") || env_getter.("AWS_REGION") || "us-east-1"

    endpoint =
      env_getter.("S3_ENDPOINT") || env_getter.("AWS_ENDPOINT_URL_S3") ||
        env_getter.("AWS_ENDPOINT_URL")

    public_url = env_getter.("S3_PUBLIC_URL")

    %{
      bucket: bucket,
      access_key_id: access_key_id,
      secret_access_key: secret_access_key,
      region: region,
      endpoint: endpoint,
      public_url: public_url
    }
  end

  defp mime_type(ext) do
    case ext do
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".png" -> "image/png"
      ".webp" -> "image/webp"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      _ -> "application/octet-stream"
    end
  end
end
