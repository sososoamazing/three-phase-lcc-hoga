function plot_accuracy_analysis
% 仅读取已保存结果：补图、导出波形、独立核对；不调用任何模型求解器或sim。
% MATLAB R2024b。新增图每文件一图，300 dpi PNG及矢量PDF。
root=fileparts(fileparts(mfilename('fullpath')));
report=fullfile(root,'06_reports');out=fullfile(report,'accuracy_analysis');
figdir=fullfile(out,'figures');datadir=fullfile(out,'data');
if ~isfolder(figdir),mkdir(figdir);end
if ~isfolder(datadir),mkdir(datadir);end
E=readtable(fullfile(report,'Point_Errors.csv'),TextType='string');
P=readtable(fullfile(report,'Point_Results.csv'),TextType='string');
O=readtable(fullfile(report,'Harmonic_Convergence.csv'));
models=["HOGA","EDF","FHA"];colors=[.05 .35 .75;.85 .35 .08;.45 .2 .65];
styles={'o--','s-.','d:'};ibase=50/sqrt(4.7e-6/135e-9);
for Vo=[100 400 800]
    T=E(E.reference=="EVENT_ODE" & E.Vo==Vo,:);
    writetable(T,fullfile(datadir,sprintf('frequency_error_V%d.csv',Vo)));
    f=newfig();
    for m=1:3
        a=sortrows(T(T.model==models(m),:),'fs');y=abs(a.Io_error_A);
        y(y==0 | a.Io_reference_A==0)=NaN; % 全截止零输出点保留CSV，不显示浮点零残差
        semilogy(a.fs/1e3,y,styles{m},Color=colors(m,:),DisplayName=models(m));
        bad=logical(a.outside_CCM);
        semilogy(a.fs(bad)/1e3,y(bad),'x',Color=colors(m,:),MarkerSize=11,HandleVisibility='off');
    end
    set(gca,'YScale','log');xticks([240 260 280 300 320]);xlim([238 322]);
    xlabel('开关频率 f_s / kHz');ylabel('|平均输出电流误差| / A（对数轴）');
    title({sprintf('V_o = %d V，V_{in} = 50 V；参考：独立事件 ODE',Vo), ...
        '圆/方/菱形为真实计算点；×为非 CCM'});
    if Vo==800
        text(242,1e-4,{'240/260 kHz：全截止，三模型误差约为零', ...
            '零输出点不绘于对数轴，原值保留于CSV'}, ...
            FontName='Microsoft YaHei',FontSize=10,BackgroundColor='w');
    end
    finish(f,sprintf('frequency_error_V%d',Vo));
end
for spec={ {'Irms_MAE_A','谐振电流 RMS 三相平均绝对误差 / A','voltage_rms_error'}, ...
           {'Ipeak_MAE_A','谐振电流峰值三相平均绝对误差 / A','voltage_peak_error'} }
    s=spec{1};T=E(E.reference=="EVENT_ODE" & E.fs==280000,:);
    writetable(T,fullfile(datadir,[s{3} '.csv']));f=newfig();
    for m=1:3
        a=sortrows(T(T.model==models(m),:),'Vo');
        semilogy(a.Vo,a.(s{1}),styles{m},Color=colors(m,:),DisplayName=models(m));
        bad=logical(a.outside_CCM);
        semilogy(a.Vo(bad),a.(s{1})(bad),'x',Color=colors(m,:),MarkerSize=11,HandleVisibility='off');
    end
    set(gca,'YScale','log');xticks(100:100:800);xlim([90 810]);
    xlabel('输出电压 V_o / V');ylabel(s{2});
    title({'V_{in} = 50 V，f_s = 280 kHz；参考：独立事件 ODE', ...
        '三相分别求误差再平均；×为非 CCM；EDF/FHA峰值来自基波重构'});
    finish(f,s{3});
end
f=newfig();cols=[.05 .35 .75;.85 .35 .08;.45 .2 .65;.1 .5 .35];st={'o-','s--','d-.','^:'};
for k=1:4
    volts=[100 400 700 800];v=volts(k);a=O(O.Vo==v,:);
    semilogy(a.H,a.Irms_max_error_A,st{k},Color=cols(k,:),DisplayName=sprintf('%d V',v));
end
set(gca,'YScale','log');xticks([1 3 5 7 9 15 31]);
xlabel('最高保留谐波阶数 H');ylabel('三相 RMS 最大绝对误差 / A');
title({'HOGA 阶数实验：f_s = 280 kHz，V_{in} = 50 V', ...
    '28 个已保存计算点；800 V 为非 CCM；参考：独立事件 ODE'});
finish(f,'order_rms_error');writetable(O,fullfile(datadir,'harmonic_order_plot_data.csv'));

% 独立读取最终MAT：不同于原compare辅助函数，逐相/逐样本重算。
rawchecks=struct([]);derived=struct([]);orderStatus=struct([]);parameterChecks=struct([]);
for k=1:height(P)
    r=P(k,:);file=fullfile(root,'05_verification','data','campaign',sprintf('%s_V%d_f%d.mat',r.model,r.Vo,r.fs));
    rec=fullfile(root,'05_verification','data','recovery',sprintf('%s_V%d_f%d.mat',r.model,r.Vo,r.fs));
    if isfile(rec),file=rec;end
    d=load(file);result=d.result;
    expected=struct('Vin',50,'Ls',4.7e-6,'Cs',135e-9,'Cp_delta',27e-9, ...
        'n_sp',4,'Rin',1e-3,'Vf_rect',0.6);
    fields=fieldnames(expected);
    for ii=1:numel(fields)
        fld=fields{ii};assert(abs(d.cfg.(fld)-expected.(fld))<1e-14,'Saved parameters differ');
    end
    parameterChecks=[parameterChecks struct('model',char(r.model),'Vo',r.Vo,'fs',r.fs, ...
        'Vin',d.cfg.Vin,'Ls',d.cfg.Ls,'Cs',d.cfg.Cs,'Cp_delta',d.cfg.Cp_delta, ...
        'n_sp',d.cfg.n_sp,'Rin',d.cfg.Rin,'Vf_rect',d.cfg.Vf_rect,'passed',true)]; %#ok<AGROW>
    assert(result.converged && r.converged,'Final dataset includes an invalid point');
    assert(abs(result.Io_avg-r.Io)<1e-11,'CSV and saved result disagree');
    assert(d.op.Vo==r.Vo && d.op.fs==r.fs);
    w=result.waveform;assert(size(w.i_A,1)==8192 && size(w.i_A,2)==3);
    if r.fs==280000 && ismember(r.Vo,[100 400 800])
        T=table(w.tau,w.i_A(:,1),w.i_A(:,2),w.i_A(:,3), ...
            w.vDelta_V(:,1),w.vDelta_V(:,2),w.vDelta_V(:,3), ...
            VariableNames={'tau','iA_A','iB_A','iC_A','vDelta1_V','vDelta2_V','vDelta3_V'});
        writetable(T,fullfile(datadir,sprintf('wave_%s_V%d.csv',r.model,r.Vo)));
    end
    if r.model=="REFERENCE",continue;end
    ref=load(fullfile(root,'05_verification','data','campaign',sprintf('REFERENCE_V%d_f%d.mat',r.Vo,r.fs)));
    rawchecks=[rawchecks metriccheck(result,ref.result,r,'EVENT_ODE')]; %#ok<AGROW>
    rw=ref.result.waveform;err=w.i_A-rw.i_A;
    F=fft(rw.i_A)/size(rw.i_A,1);frms=sqrt(2)*abs(F(2,:));
    thd=sqrt(max(0,mean(rw.i_A.^2,1)-abs(F(1,:)).^2-frms.^2))./frms;
    zshift=[];
    for phase=1:3
        for dir=[-1 1]
            z=zerotimes(w.tau,w.i_A(:,phase),dir);zr=zerotimes(rw.tau,rw.i_A(:,phase),dir);
            if isscalar(z) && isscalar(zr),zshift(end+1)=mod(z-zr+.5,1)-.5;end %#ok<AGROW>
        end
    end
    derived=[derived struct('model',char(r.model),'Vo',r.Vo,'fs',r.fs, ...
        'reference_THD_max_percent',100*max(thd),'zero_crossings_matched',numel(zshift), ...
        'zero_shift_max_ns',max(abs(zshift))/r.fs*1e9, ...
        'wave_max_A',max(abs(err),[],'all'), ...
        'wave_NRMSE_percent',100*sqrt(mean(err.^2,'all'))/ibase)]; %#ok<AGROW>
end
for Vo=[100 400 800]
    d=load(fullfile(root,'05_verification','data',sprintf('simulink_V%d_fine_integrated.mat',Vo)));
    w=d.waveform;T=table(w.tau,w.i_A(:,1),w.i_A(:,2),w.i_A(:,3), ...
        VariableNames={'tau','iA_A','iB_A','iC_A'});
    writetable(T,fullfile(datadir,sprintf('wave_SIMULINK_V%d.csv',Vo)));
    sr=struct('Io_avg',d.record.Io,'Ir_rms',d.record.Irms,'Ir_peak',d.record.Ipeak,'waveform',w);
    for m=1:3
        md=load(fullfile(root,'05_verification','data','campaign',sprintf('%s_V%d_f280000.mat',models(m),Vo)));
        rr=struct('model',models(m),'Vo',Vo,'fs',280000);
        rawchecks=[rawchecks metriccheck(md.result,sr,rr,'SIMULINK_FINE')]; %#ok<AGROW>
    end
end
for k=1:height(O)
    d=load(fullfile(root,'00_audit','data','stage1_run02',sprintf('original_V%d_H%d.mat',O.Vo(k),O.H(k))));
    h=d.hoga;orderStatus=[orderStatus struct('Vo',O.Vo(k),'H',O.H(k), ...
        'algebraic_converged',h.converged_algebraic,'physical_guard_pass',h.physical_guard_pass, ...
        'normal_max_V',h.metric.normal_max_V,'min_diode_current_A',h.metric.min_diode_current_signed_A, ...
        'power_relative_residual',h.metric.power_relative_residual, ...
        'solve_only_s',d.elapsed)]; %#ok<AGROW>
end
writetable(struct2table(rawchecks),fullfile(datadir,'independent_raw_metric_check.csv'));
writetable(struct2table(derived),fullfile(datadir,'waveform_diagnostics.csv'));
writetable(struct2table(orderStatus),fullfile(datadir,'order_status.csv'));
writetable(struct2table(parameterChecks),fullfile(datadir,'saved_parameter_checks.csv'));
issues=checkcode(mfilename('fullpath'),'-struct');
fid=fopen(fullfile(out,'matlab_checkcode.json'),'w');fprintf(fid,'%s',jsonencode(issues,PrettyPrint=true));fclose(fid);
fprintf('ACCURACY_ANALYSIS_PLOTS_COMPLETE; no numerical model or Simulink solve executed\n');
    function f=newfig()
        f=figure('Visible','off','Color','w','Position',[100 100 1120 690]);
        ax=axes(f,'Position',[.14 .14 .81 .73]);hold(ax,'on');set(ax,'FontName','Microsoft YaHei','FontSize',12,'LineWidth',.8);
        colororder(colors);grid on;box on;
    end
    function finish(f,name)
        set(findobj(f,'Type','line'),'LineWidth',1.6);legend('Location','best','FontSize',11);
        set(f,'PaperUnits','inches','PaperSize',[11.2 6.9],'PaperPosition',[0 0 11.2 6.9]);
        print(f,fullfile(figdir,[name '.png']),'-dpng','-r300');
        print(f,fullfile(figdir,[name '.pdf']),'-dpdf','-painters');close(f);
    end
    function row=metriccheck(r,ref,record,reference)
        di=r.waveform.i_A-ref.waveform.i_A;
        row=struct('reference',reference,'model',char(record.model),'Vo',record.Vo,'fs',record.fs, ...
            'Io_error_A',r.Io_avg-ref.Io_avg, ...
            'Irms_MAE_A',sum(abs(r.Ir_rms-ref.Ir_rms))/3, ...
            'Irms_max_abs_A',max(abs(r.Ir_rms-ref.Ir_rms)), ...
            'Ipeak_MAE_A',sum(abs(r.Ir_peak-ref.Ir_peak))/3, ...
            'Ipeak_max_abs_A',max(abs(r.Ir_peak-ref.Ir_peak)), ...
            'wave_NRMSE_Ibase',sqrt(sum(di(:).^2)/numel(di))/ibase, ...
            'wave_max_abs_A',max(abs(di(:))));
    end
end
function z=zerotimes(t,y,direction)
t=[t;1];y=[y;y(1)];k=find(y(1:end-1).*y(2:end)<=0 & sign(diff(y))==direction);
z=t(k)-y(k).*(t(k+1)-t(k))./(y(k+1)-y(k));
z=unique(mod(z,1));
end
