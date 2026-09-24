defmodule Quizir.Storage do
  @moduledoc """
  Handles file uploads to S3.
  Image uploading can only be activated if an S3 configuration via environment variables is active.
  """

  require Logger

  @doc """
  Checks if S3 upload is configured via environment variables.
  """
  def s3_configured? do
    case Application.get_env(:quizir, :s3_configured_override) do
      val when is_boolean(val) ->
        val

      _ ->
        s3_configured?(&System.get_env/1)
    end
  end

  def s3_configured?(env_getter) when is_function(env_getter, 1) do
    config = get_s3_config(env_getter)
    config.bucket != nil and config.access_key_id != nil and config.secret_access_key != nil
  end

  @max_image_bytes 500 * 1024
  @max_dimension 1024

  @doc """
  Returns the maximum allowed image size in bytes (500 KiB = 512,000 bytes).
  """
  def max_image_bytes, do: @max_image_bytes

  @doc """
  Returns the maximum allowed image dimension (width/height) in pixels.
  """
  def max_dimension, do: @max_dimension

  @doc """
  Uploads a file to S3 after optimizing, resizing to max 1024x1024,
  and verifying that its weight does not exceed 500 KiB.
  Returns `{:ok, url}` or `{:error, reason}`.
  Upload is strictly disabled if S3 is not configured via environment variables.
  If the file exceeds 500 KiB after optimization, returns `{:error, :file_too_large}`.
  """
  def upload_file(local_path, original_filename) do
    if s3_configured?() do
      case Application.get_env(:quizir, :storage_test_uploader) do
        fun when is_function(fun, 2) ->
          fun.(local_path, original_filename)

        _ ->
          ext = Path.extname(original_filename) |> String.downcase()

          case optimize_and_validate(local_path, ext) do
            {:ok, file_to_upload, cleanup_needed?} ->
              random_id = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)

              sanitized_name =
                Path.basename(original_filename, ext) |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")

              key = "uploads/#{random_id}_#{sanitized_name}#{ext}"
              content_type = mime_type(ext)

              result = upload_to_s3(file_to_upload, key, content_type)

              if cleanup_needed?, do: File.rm(file_to_upload)

              result

            {:error, reason} ->
              {:error, reason}
          end
      end
    else
      {:error, :s3_not_configured}
    end
  end

  @doc """
  Optimizes and resizes an image if possible, and verifies that its size does not exceed 500 KiB.
  Returns `{:ok, path_to_file, cleanup_needed?}` or `{:error, reason}`.
  """
  def optimize_and_validate(local_path, ext) do
    case optimize_image(local_path, ext) do
      {:ok, optimized_path} ->
        case File.stat(optimized_path) do
          {:ok, %{size: size}} when size <= @max_image_bytes ->
            {:ok, optimized_path, true}

          {:ok, %{size: size}} ->
            File.rm(optimized_path)
            Logger.warning("Image exceeds 500 KiB after optimization: #{size} bytes")
            {:error, :file_too_large}

          {:error, reason} ->
            File.rm(optimized_path)
            {:error, reason}
        end

      {:error, _reason} ->
        case File.stat(local_path) do
          {:ok, %{size: size}} when size <= @max_image_bytes ->
            {:ok, local_path, false}

          {:ok, %{size: size}} ->
            Logger.warning("Image exceeds 500 KiB and could not be optimized: #{size} bytes")
            {:error, :file_too_large}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp optimize_image(local_path, ext) when ext in [".jpg", ".jpeg", ".png", ".webp", ".gif"] do
    ffmpeg = System.find_executable("ffmpeg")
    convert = System.find_executable("magick") || System.find_executable("convert")

    tmp_dir = System.tmp_dir!()
    random_str = :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)
    target_path = Path.join(tmp_dir, "opt_#{random_str}#{ext}")

    cond do
      ffmpeg != nil ->
        args =
          case ext do
            ext when ext in [".jpg", ".jpeg"] ->
              [
                "-y",
                "-i",
                local_path,
                "-vf",
                "scale='min(#{@max_dimension},iw)':'min(#{@max_dimension},ih)':force_original_aspect_ratio=decrease",
                "-q:v",
                "3",
                "-frames:v",
                "1",
                "-update",
                "1",
                target_path
              ]

            ".png" ->
              [
                "-y",
                "-i",
                local_path,
                "-vf",
                "scale='min(#{@max_dimension},iw)':'min(#{@max_dimension},ih)':force_original_aspect_ratio=decrease",
                "-frames:v",
                "1",
                "-update",
                "1",
                target_path
              ]

            ".webp" ->
              [
                "-y",
                "-i",
                local_path,
                "-vf",
                "scale='min(#{@max_dimension},iw)':'min(#{@max_dimension},ih)':force_original_aspect_ratio=decrease",
                "-frames:v",
                "1",
                "-update",
                "1",
                target_path
              ]

            ".gif" ->
              [
                "-y",
                "-i",
                local_path,
                "-vf",
                "scale='min(#{@max_dimension},iw)':'min(#{@max_dimension},ih)':force_original_aspect_ratio=decrease",
                target_path
              ]
          end

        case System.cmd(ffmpeg, args, stderr_to_stdout: true) do
          {_output, 0} ->
            if File.exists?(target_path) do
              {:ok, target_path}
            else
              {:error, :ffmpeg_output_missing}
            end

          {output, code} ->
            Logger.debug("ffmpeg optimization failed (exit #{code}): #{output}")
            {:error, :optimization_failed}
        end

      convert != nil ->
        args = [
          local_path,
          "-resize",
          "#{@max_dimension}x#{@max_dimension}>",
          "-quality",
          "85",
          target_path
        ]

        case System.cmd(convert, args, stderr_to_stdout: true) do
          {_output, 0} ->
            if File.exists?(target_path) do
              {:ok, target_path}
            else
              {:error, :convert_output_missing}
            end

          {output, code} ->
            Logger.debug("convert optimization failed (exit #{code}): #{output}")
            {:error, :optimization_failed}
        end

      true ->
        {:error, :no_optimizer_available}
    end
  end

  defp optimize_image(_local_path, _ext), do: {:error, :unsupported_format}

  defp upload_to_s3(local_path, key, content_type) do
    config = get_s3_config()

    case File.read(local_path) do
      {:ok, body} ->
        req = build_s3_req(config)
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

  @doc false
  def build_s3_req(config) do
    sigv4_opts = [
      access_key_id: config.access_key_id,
      secret_access_key: config.secret_access_key,
      region: config.region
    ]

    req_opts = [aws_sigv4: sigv4_opts]

    req_opts =
      if config.endpoint do
        Keyword.put(req_opts, :aws_endpoint_url_s3, config.endpoint)
      else
        req_opts
      end

    Req.new() |> ReqS3.attach(req_opts)
  end

  @doc """
  Deletes an uploaded file from S3 if possible.
  """
  def delete_file(url) when is_binary(url) do
    case Application.get_env(:quizir, :storage_test_deleter) do
      fun when is_function(fun, 1) ->
        fun.(url)

      _ ->
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
              req = build_s3_req(config)
              s3_url = "s3://#{config.bucket}/#{key}"
              Req.delete(req, url: s3_url)
              :ok
            else
              :ok
            end

          true ->
            :ok
        end
    end
  rescue
    _ -> :ok
  end

  def delete_file(_), do: :ok

  defp extract_s3_key(url, config) do
    cond do
      config.bucket && String.contains?(url, "/#{config.bucket}/") ->
        [_, key] = String.split(url, "/#{config.bucket}/", parts: 2)
        key

      config.public_url && String.starts_with?(url, config.public_url) ->
        String.replace_prefix(url, String.trim_trailing(config.public_url, "/") <> "/", "")

      true ->
        case URI.parse(url).path do
          nil -> nil
          path -> String.trim_leading(path, "/")
        end
    end
  end

  defp build_public_url(config, key) do
    cond do
      config.public_url &&
          (String.contains?(config.public_url, config.bucket) or
             URI.parse(config.public_url).path not in [nil, "", "/"]) ->
        "#{String.trim_trailing(config.public_url, "/")}/#{key}"

      config.public_url ->
        "#{String.trim_trailing(config.public_url, "/")}/#{config.bucket}/#{key}"

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
