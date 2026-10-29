class ApplicationMailer < ActionMailer::Base
  # Every McRitchie app sends from team@mcritchie.studio under its own name
  # (Alex McRitchie's ruling, 2026-10-28); a client's own sending domain is a
  # tier upgrade, set through MAILER_FROM. Chain Ops does not run on studio-engine,
  # so there is no Studio.mailer_from to read. The Rails scaffold's
  # placeholder sender sat here, which Resend refuses.
  default from: -> { ENV["MAILER_FROM"].presence || "Chain Ops <team@mcritchie.studio>" }
  layout "mailer"
end
