defmodule Messaging.Conversations.MessageTest do
  use ExUnit.Case, async: true

  alias Messaging.Conversations.Message

  @valid_attrs %{
    conversation_id: "conv-123",
    from_address: "+12016661234",
    to_address: "+18045551234",
    message_type: "sms",
    body: "Hello, this is a test message",
    direction: "outbound",
    timestamp: DateTime.utc_now()
  }

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      changeset = Message.changeset(%Message{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :conversation_id) == "conv-123"
      assert get_change(changeset, :from_address) == "+12016661234"
      assert get_change(changeset, :to_address) == "+18045551234"
      assert get_change(changeset, :message_type) == "sms"
      assert get_change(changeset, :body) == "Hello, this is a test message"
      assert get_change(changeset, :direction) == "outbound"
    end

    test "creates valid changeset with all optional fields" do
      attrs =
        Map.merge(@valid_attrs, %{
          attachments: ["https://example.com/file1.jpg", "https://example.com/file2.pdf"],
          provider_id: "provider-msg-123"
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :attachments) == ["https://example.com/file1.jpg", "https://example.com/file2.pdf"]
      assert get_change(changeset, :provider_id) == "provider-msg-123"
    end

    test "creates valid changeset for MMS message" do
      attrs =
        Map.merge(@valid_attrs, %{
          message_type: "mms",
          attachments: ["https://example.com/image.jpg"]
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :message_type) == "mms"
    end

    test "creates valid changeset for email message" do
      attrs =
        Map.merge(@valid_attrs, %{
          from_address: "user@example.com",
          to_address: "contact@example.com",
          message_type: "email",
          body: "<html><body>Email with <b>HTML</b></body></html>",
          attachments: ["https://example.com/document.pdf"]
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :message_type) == "email"
    end

    test "creates valid changeset for inbound message" do
      attrs =
        Map.merge(@valid_attrs, %{
          direction: "inbound",
          provider_id: "provider-inbound-123"
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :direction) == "inbound"
    end
  end

  describe "required field validation" do
    test "requires conversation_id" do
      attrs = Map.delete(@valid_attrs, :conversation_id)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{conversation_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires from_address" do
      attrs = Map.delete(@valid_attrs, :from_address)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{from_address: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires to_address" do
      attrs = Map.delete(@valid_attrs, :to_address)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{to_address: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires message_type" do
      attrs = Map.delete(@valid_attrs, :message_type)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{message_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires body" do
      attrs = Map.delete(@valid_attrs, :body)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires direction" do
      attrs = Map.delete(@valid_attrs, :direction)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{direction: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires timestamp" do
      attrs = Map.delete(@valid_attrs, :timestamp)
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{timestamp: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not require attachments" do
      changeset = Message.changeset(%Message{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :attachments) == nil
    end

    test "does not require provider_id" do
      changeset = Message.changeset(%Message{}, @valid_attrs)

      assert changeset.valid?
      assert get_change(changeset, :provider_id) == nil
    end
  end

  describe "message_type validation" do
    test "accepts valid message types" do
      for message_type <- ["sms", "mms", "email"] do
        attrs = Map.put(@valid_attrs, :message_type, message_type)
        changeset = Message.changeset(%Message{}, attrs)

        assert changeset.valid?, "#{message_type} should be valid"
      end
    end

    test "rejects invalid message types" do
      invalid_types = ["voice", "fax", "telegram", "slack"]

      for invalid_type <- invalid_types do
        attrs = Map.put(@valid_attrs, :message_type, invalid_type)
        changeset = Message.changeset(%Message{}, attrs)

        refute changeset.valid?, "#{invalid_type} should be invalid"
        assert %{message_type: ["is invalid"]} = errors_on(changeset)
      end
    end

    test "rejects empty string message type" do
      attrs = Map.put(@valid_attrs, :message_type, "")
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{message_type: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "direction validation" do
    test "accepts valid directions" do
      for direction <- ["inbound", "outbound"] do
        attrs = Map.put(@valid_attrs, :direction, direction)
        changeset = Message.changeset(%Message{}, attrs)

        assert changeset.valid?, "#{direction} should be valid"
      end
    end

    test "rejects invalid directions" do
      invalid_directions = ["incoming", "outgoing", "sent", "received"]

      for invalid_direction <- invalid_directions do
        attrs = Map.put(@valid_attrs, :direction, invalid_direction)
        changeset = Message.changeset(%Message{}, attrs)

        refute changeset.valid?, "#{invalid_direction} should be invalid"
        assert %{direction: ["is invalid"]} = errors_on(changeset)
      end
    end

    test "rejects empty string direction" do
      attrs = Map.put(@valid_attrs, :direction, "")
      changeset = Message.changeset(%Message{}, attrs)

      refute changeset.valid?
      assert %{direction: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "attachment validation" do
    test "accepts nil attachments" do
      attrs = Map.put(@valid_attrs, :attachments, nil)
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "accepts empty list of attachments" do
      attrs = Map.put(@valid_attrs, :attachments, [])
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "accepts list of string URLs" do
      attachments = [
        "https://example.com/file1.jpg",
        "https://example.com/file2.pdf",
        "https://example.com/file3.doc"
      ]

      attrs = Map.put(@valid_attrs, :attachments, attachments)
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "rejects list with non-string items" do
      invalid_attachments = [
        ["https://example.com/file1.jpg", 123, "https://example.com/file2.pdf"],
        ["https://example.com/file1.jpg", %{"url" => "test"}],
        [true, false]
      ]

      for attachments <- invalid_attachments do
        attrs = Map.put(@valid_attrs, :attachments, attachments)
        changeset = Message.changeset(%Message{}, attrs)

        refute changeset.valid?
        assert %{attachments: ["is invalid"]} = errors_on(changeset)
      end
    end

    test "handles nil items in list by filtering them out" do
      # Ecto's {:array, :string} type filters out nil values
      attrs = Map.put(@valid_attrs, :attachments, ["https://example.com/file1.jpg", nil])
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
      # The nil should be filtered out by Ecto
    end

    test "rejects non-list attachments" do
      invalid_attachments = ["string", 123, true, :atom, %{"files" => ["url"]}]

      for attachments <- invalid_attachments do
        attrs = Map.put(@valid_attrs, :attachments, attachments)
        changeset = Message.changeset(%Message{}, attrs)

        refute changeset.valid?
        assert %{attachments: ["is invalid"]} = errors_on(changeset)
      end
    end

    test "validates attachment URL length" do
      # Valid length URLs should work
      normal_url = "https://example.com/file.jpg"
      attrs = Map.put(@valid_attrs, :attachments, [normal_url])
      changeset = Message.changeset(%Message{}, attrs)
      
      assert changeset.valid?
    end

    test "rejects overly long attachment URLs" do
      # Create a URL longer than 2048 characters
      long_path = String.duplicate("very-long-path-segment/", 100)
      long_url = "https://example.com/#{long_path}file.jpg"
      
      attrs = Map.put(@valid_attrs, :attachments, [long_url])
      changeset = Message.changeset(%Message{}, attrs)
      
      refute changeset.valid?
      assert %{attachments: ["contains invalid or overly long URLs"]} = errors_on(changeset)
    end

    test "handles empty strings in attachments (Ecto filters them out)" do
      # Ecto's {:array, :string} type filters out empty strings automatically
      attrs = Map.put(@valid_attrs, :attachments, ["", "https://example.com/valid.jpg", ""])
      changeset = Message.changeset(%Message{}, attrs)
      
      assert changeset.valid?
      # Empty strings should be filtered out, leaving only the valid URL
      assert Ecto.Changeset.get_field(changeset, :attachments) == ["https://example.com/valid.jpg"]
    end

    test "rejects very short attachment URLs" do
      attrs = Map.put(@valid_attrs, :attachments, ["x.y"])  # Only 3 characters
      changeset = Message.changeset(%Message{}, attrs)
      
      refute changeset.valid?
      assert %{attachments: ["contains invalid or overly long URLs"]} = errors_on(changeset)
    end

    test "allows mixed valid and checks all URLs" do
      # One valid, one invalid - should fail
      mixed_urls = ["https://example.com/valid.jpg", String.duplicate("x", 2049)]
      attrs = Map.put(@valid_attrs, :attachments, mixed_urls)
      changeset = Message.changeset(%Message{}, attrs)
      
      refute changeset.valid?
      assert %{attachments: ["contains invalid or overly long URLs"]} = errors_on(changeset)
    end
  end

  describe "field types and constraints" do
    test "handles unicode characters in addresses" do
      attrs =
        Map.merge(@valid_attrs, %{
          from_address: "📱+12016661234🌟",
          to_address: "💌contact@example.com🎉"
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "handles very long body text" do
      long_body = String.duplicate("This is a very long message. ", 1000)
      attrs = Map.put(@valid_attrs, :body, long_body)
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "handles empty strings in optional fields" do
      attrs = Map.put(@valid_attrs, :provider_id, "")
      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "handles HTML in body for email messages" do
      html_body = """
      <html>
        <body>
          <h1>Welcome!</h1>
          <p>This is an <strong>HTML</strong> email with <a href="https://example.com">links</a>.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
        </body>
      </html>
      """

      attrs =
        Map.merge(@valid_attrs, %{
          message_type: "email",
          body: html_body
        })

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end
  end

  describe "real-world message examples" do
    test "validates SMS outbound message" do
      attrs = %{
        conversation_id: "conv-sms-123",
        from_address: "+12016661234",
        to_address: "+18045551234",
        message_type: "sms",
        body: "Hello! This is a test SMS message.",
        attachments: nil,
        direction: "outbound",
        timestamp: "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      }

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "validates MMS inbound message" do
      attrs = %{
        conversation_id: "conv-mms-456",
        from_address: "+18045551234",
        to_address: "+12016661234",
        message_type: "mms",
        body: "This is an incoming MMS message",
        attachments: ["https://example.com/received-image.jpg"],
        provider_id: "msg-provider-789",
        direction: "inbound",
        timestamp: "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      }

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "validates email outbound message" do
      attrs = %{
        conversation_id: "conv-email-789",
        from_address: "user@usehatchapp.com",
        to_address: "contact@gmail.com",
        message_type: "email",
        body: "Hello! This is a test email message with <b>HTML</b> formatting.",
        attachments: ["https://example.com/document.pdf"],
        direction: "outbound",
        timestamp: "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      }

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end

    test "validates email inbound webhook" do
      attrs = %{
        conversation_id: "conv-email-webhook-456",
        from_address: "contact@gmail.com",
        to_address: "user@usehatchapp.com",
        message_type: "email",
        body: "<html><body>This is an incoming email with <b>HTML</b> content</body></html>",
        attachments: ["https://example.com/received-document.pdf"],
        provider_id: "xillio-msg-789",
        direction: "inbound",
        timestamp: "2024-11-01T14:00:00Z" |> DateTime.from_iso8601() |> elem(1)
      }

      changeset = Message.changeset(%Message{}, attrs)

      assert changeset.valid?
    end
  end

  # Helper function to extract validation errors
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  # Helper function to get changeset changes
  defp get_change(changeset, key) do
    Ecto.Changeset.get_change(changeset, key)
  end
end
