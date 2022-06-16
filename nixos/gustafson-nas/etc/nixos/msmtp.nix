{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    msmtp
  ];

  environment.etc.msmtprc.text = ''
    # Set default values for all following accounts.
    defaults
    auth           on
    tls            on
    #tls_trust_file /etc/ssl/certs/ca-certificates.crt
    #logfile        ~/.msmtp.log

    # Gmail
    account        gmail
    host           smtp.gmail.com
    port           587
    from           joshgstfsn@gmail.com
    user           joshgstfsn
    password       qubinsyawfntszqd

    # Set a default account
    account default : gmail
  '';
}
