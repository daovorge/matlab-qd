function run_magnet_daemon()
    json.startup();
    qd.util.change_matlab_title('Magnet Daemon');;
    magnet = qd.daemons.OxfMagnet3D('COM?')
%    magnet.server.smtp_server = 'mail.fys.ku.dk';
%    magnet.server.alert_email = 'mail@example.com';
    magnet.run_daemon();
end