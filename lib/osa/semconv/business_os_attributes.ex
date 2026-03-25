defmodule OpenTelemetry.SemConv.Incubating.BusinessOsAttributes do
  @moduledoc """
  BusinessOs semantic convention attributes.

  Namespace: `business_os`

  This module is generated from the ChatmanGPT semantic convention registry.
  Do not edit manually — regenerate with:

      weaver registry generate -r ./semconv/model --templates ./semconv/templates elixir ./OSA/lib/osa/semconv/
  """

  @doc """
  Type of audit event in the BusinessOS audit trail.

  Attribute: `business_os.audit.event_type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `create`, `access`
  """
  @spec business_os_audit_event_type() :: :"business_os.audit.event_type"
  def business_os_audit_event_type, do: :"business_os.audit.event_type"

  @doc """
  Enumerated values for `business_os.audit.event_type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `create` | `"create"` | create |
  | `update` | `"update"` | update |
  | `delete` | `"delete"` | delete |
  | `access` | `"access"` | access |
  | `export` | `"export"` | export |
  """
  @spec business_os_audit_event_type_values() :: %{
    create: :create,
    update: :update,
    delete: :delete,
    access: :access,
    export: :export
  }
  def business_os_audit_event_type_values do
    %{
      create: :create,
      update: :update,
      delete: :delete,
      access: :access,
      export: :export
    }
  end

  defmodule BusinessOsAuditEventTypeValues do
    @moduledoc """
    Typed constants for the `business_os.audit.event_type` attribute.
    """

    @doc "create"
    @spec create() :: :create
    def create, do: :create

    @doc "update"
    @spec update() :: :update
    def update, do: :update

    @doc "delete"
    @spec delete() :: :delete
    def delete, do: :delete

    @doc "access"
    @spec access() :: :access
    def access, do: :access

    @doc "export"
    @spec export() :: :export
    def export, do: :export

  end

  @doc """
  The compliance framework being evaluated or enforced.

  Attribute: `business_os.compliance.framework`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `SOC2`, `HIPAA`
  """
  @spec business_os_compliance_framework() :: :"business_os.compliance.framework"
  def business_os_compliance_framework, do: :"business_os.compliance.framework"

  @doc """
  Enumerated values for `business_os.compliance.framework`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `soc2` | `"SOC2"` | SOC2 |
  | `hipaa` | `"HIPAA"` | HIPAA |
  | `gdpr` | `"GDPR"` | GDPR |
  | `sox` | `"SOX"` | SOX |
  """
  @spec business_os_compliance_framework_values() :: %{
    soc2: :SOC2,
    hipaa: :HIPAA,
    gdpr: :GDPR,
    sox: :SOX
  }
  def business_os_compliance_framework_values do
    %{
      soc2: :SOC2,
      hipaa: :HIPAA,
      gdpr: :GDPR,
      sox: :SOX
    }
  end

  defmodule BusinessOsComplianceFrameworkValues do
    @moduledoc """
    Typed constants for the `business_os.compliance.framework` attribute.
    """

    @doc "SOC2"
    @spec soc2() :: :SOC2
    def soc2, do: :SOC2

    @doc "HIPAA"
    @spec hipaa() :: :HIPAA
    def hipaa, do: :HIPAA

    @doc "GDPR"
    @spec gdpr() :: :GDPR
    def gdpr, do: :GDPR

    @doc "SOX"
    @spec sox() :: :SOX
    def sox, do: :SOX

  end

  @doc """
  The integration pattern used to connect an external service.

  Attribute: `business_os.integration.type`
  Type: `enum`
  Stability: `development`
  Requirement: `recommended`
  Examples: `webhook`, `api_pull`
  """
  @spec business_os_integration_type() :: :"business_os.integration.type"
  def business_os_integration_type, do: :"business_os.integration.type"

  @doc """
  Enumerated values for `business_os.integration.type`.

  | Key | Value | Description |
  |-----|-------|-------------|
  | `webhook` | `"webhook"` | webhook |
  | `api_pull` | `"api_pull"` | api_pull |
  | `file_sync` | `"file_sync"` | file_sync |
  | `realtime_stream` | `"realtime_stream"` | realtime_stream |
  """
  @spec business_os_integration_type_values() :: %{
    webhook: :webhook,
    api_pull: :api_pull,
    file_sync: :file_sync,
    realtime_stream: :realtime_stream
  }
  def business_os_integration_type_values do
    %{
      webhook: :webhook,
      api_pull: :api_pull,
      file_sync: :file_sync,
      realtime_stream: :realtime_stream
    }
  end

  defmodule BusinessOsIntegrationTypeValues do
    @moduledoc """
    Typed constants for the `business_os.integration.type` attribute.
    """

    @doc "webhook"
    @spec webhook() :: :webhook
    def webhook, do: :webhook

    @doc "api_pull"
    @spec api_pull() :: :api_pull
    def api_pull, do: :api_pull

    @doc "file_sync"
    @spec file_sync() :: :file_sync
    def file_sync, do: :file_sync

    @doc "realtime_stream"
    @spec realtime_stream() :: :realtime_stream
    def realtime_stream, do: :realtime_stream

  end

end