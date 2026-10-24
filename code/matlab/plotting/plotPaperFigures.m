function plotPaperFigures()
% Publication figures from actual accepted HOGA nodes. No gap filling.
% Every figure exports vector PDF/SVG, 600 dpi PNG, editable FIG and its own MAT/CSV.
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'core'),fullfile(root,'scripts'));
figdir=fullfile(root,'figures');datadir=fullfile(figdir,'data');
if ~isfolder(figdir),mkdir(figdir);end
if ~isfolder(datadir),mkdir(datadir);end
T=readtable(fullfile(root,'tables','characteristic_domain.csv'),TextType='string');
for field=["accepted","CCM","all_six_polarity","zvs_certified"]
    T.(field)=toLogical(T.(field));
end
cfg=jsondecode(fileread(fullfile(root,'configuration.json')));
% The x axis of the characteristic figures is the resonant-tank voltage gain,
% i.e. the output voltage referred back through the transformer ratio:
%   M = Vo / (n*Vin),  n = Ns/Np = 4 (single winding), Vin = 50 V  =>  M = Vo/200.
% M = 4 corresponds to the 800 V end of the 50 V -> 800 V range.
nSp=cfg.n_sp;Vin=cfg.Vin_V;gscale=1/(nSp*Vin);Mmax=800*gscale;
if ~ismember('M',T.Properties.VariableNames),T.M=T.Vo_V*gscale;end
gainLabel=sprintf('Resonant-tank gain M = V_o/(nV_{in}),  n = %g, V_{in} = %g V',nSp,Vin);
meta=struct('generator',['plotPaperFigures.m / MATLAB ' version], ...
    'data_source','tables/characteristic_domain.csv (unique verified raw-backed nodes)', ...
    'Vin_V',cfg.Vin_V,'Ls_H',cfg.Ls_H,'Cs_F',cfg.Cs_F,'Cp_delta_F',cfg.Cp_delta_F, ...
    'n_sp',cfg.n_sp,'fr_Hz',cfg.fr_Hz,'k_definition',cfg.k_definition, ...
    'gain_definition',sprintf(['M = Vo/(n*Vin) with n=Ns/Np=%g and Vin=%g V; ' ...
        'the transformer ratio is folded into M, so M=1 is 200 V and M=4 is 800 V'],nSp,Vin), ...
    'frequency_normalization',cfg.frequency_normalization, ...
    'retained_nonidealities',sprintf('Rin=%g ohm; Vf_rect=%g V per diode',cfg.Rin_ohm,cfg.Vf_rect_V), ...
    'interpolation','none: straight display segments between accepted samples only', ...
    'open_family','all-blocked periodic family, I_o=0; existence does not prove charging reachability', ...
    'unresolved','no periodic solution passed the physical guard and order check; never interpolated', ...
    'zvs','six commutation-current polarities are a necessary condition only; no Coss/deadtime gate-drive certification');
styleFigure();
hasDCM=any(T.CCM==false & T.accepted & T.Io_A>1e-8);

% ---------------------------------------------------------------- 图1/图2/图6
selected=[1 1.1 1.2 1.4 1.5 1.6 1.8 2];C=lines(numel(selected));
for name=["Io_A","Im_A","Irms_A"]
    f=paperFigure(17.8,12.4);ax=axes(f,'Position',[.115 .225 .85 .645]);hold(ax,'on');
    D=table();H=gobjects(1,0);
    for j=1:numel(selected)
        part=T(abs(T.fn-selected(j))<1e-6 & abs(T.k_delta-.2)<1e-6,:);
        H(end+1)=plotBranch(ax,part,name,C(j,:),sprintf('f_n = %.2f',selected(j))); %#ok<AGROW>
        D=[D;seriesRows(part,sprintf('f_n=%.2f',selected(j)))]; %#ok<AGROW>
    end
    openProxy=plot(ax,NaN,NaN,':','Color',[.45 .45 .45],'LineWidth',1.0, ...
        'DisplayName','All-blocked family (I_o = 0)');
    items=[H openProxy];
    if hasDCM
        dcmProxy=plot(ax,NaN,NaN,'^','Color',[.35 .35 .35],'MarkerSize',4,'MarkerFaceColor','w', ...
            'LineStyle','none','DisplayName','DCM node');
        items=[items dcmProxy];
    end
    xlabel(ax,gainLabel);ylabel(ax,currentLabel(name));
    xlim(ax,[0 Mmax]);ylim(ax,autoLimit(D,name));grid(ax,'on');
    title(ax,'k = C_{p,\Delta}/C_s = 0.2; f_n = f_s/f_r');
    legend(ax,rowMajor(items,3),'NumColumns',3,'FontSize',8.2,'Location','northeast');
    note(f,{"Solid line with filled marker: accepted charging node. Pale dotted line: all-blocked periodic family (I_o = 0);", ...
        "its existence does not prove charging reachability. Curve gap: unresolved sample - never interpolated."});
    if name=="Io_A",file='Fig01_Io_vs_Vo_by_fn';elseif name=="Im_A",file='Fig02_Im_vs_Vo_by_fn';else,file='Fig06_Irms_vs_Vo_by_fn';end
    exportFigure(f,root,file,D,meta);
end

% ---------------------------------------------------------------------- 图3
anchorFile=fullfile(root,'tables','switch_model_anchors.csv');
anchors=table();
if isfile(anchorFile)
    anchors=readtable(anchorFile,TextType='string');
    anchors=anchors(anchors.node_class=="CHARGING_ANCHOR",:);
end
f=paperFigure(17.8,20.5);tl=tiledlayout(f,2,1,'TileSpacing','compact','Padding','compact');
tl.OuterPosition=[0 .115 1 .865];
caps=[.1 .2 .35 .5 .8 1];C=lines(6);D=table();H=gobjects(1,0);
for panel=1:2
    ax=nexttile(tl);hold(ax,'on');field="Io_A";if panel==2,field="Im_A";end
    for j=1:6
        part=T(abs(T.fn-1.4)<1e-6 & abs(T.k_delta-caps(j))<1e-6,:);
        h=plotBranch(ax,part,field,C(j,:),sprintf('k = %.2g',caps(j)),panel==1);
        if panel==1,H(end+1)=h;end %#ok<AGROW>
        D=[D;seriesRows(part,sprintf('k=%.2g',caps(j)))]; %#ok<AGROW>
    end
    anchorProxy=[];
    if ~isempty(anchors) && any(abs(caps-0.5)<1e-9)
        for a=1:height(anchors)
            if abs(anchors.k_delta(a)-0.5)>1e-9,continue;end
            if field=="Io_A",val=anchors.Io_A(a);else,val=anchors.Im_A(a);end
            anchorProxy=plot(ax,anchors.M(a),val,'o','MarkerSize',7.5,'LineWidth',1.0, ...
                'MarkerEdgeColor',[.15 .15 .15],'MarkerFaceColor','none','HandleVisibility','off');
        end
    end
    xlabel(ax,gainLabel);ylabel(ax,currentLabel(field));xlim(ax,[0 Mmax]);
    ylim(ax,autoLimit(D,field));grid(ax,'on');
    title(ax,sprintf('(%c)  f_n = 1.40; L_s and C_s fixed, only C_{p,\\Delta} changed',char('a'+panel-1)));
    if panel==1
        if isempty(anchorProxy)
            lgd=legend(ax,rowMajor(H,6),'Orientation','horizontal','NumColumns',6,'FontSize',8.2);
        else
            anchorProxy.DisplayName='k = 0.5 switch-model anchor';
            anchorProxy.HandleVisibility='on';
            lgd=legend(ax,rowMajor([H anchorProxy],7),'Orientation','horizontal','NumColumns',7,'FontSize',7.6);
        end
        lgd.Layout.Tile='south';
    end
end
note(f,{"k is defined per delta edge: k = C_{p,\Delta}/C_s, so the balanced star equivalent is 3k. Only C_{p,\Delta} changes; f_r is not re-referenced.", ...
    "Pale dotted line: all-blocked periodic family (I_o = 0). Curve gap: no accepted HOGA solution at that voltage. Open circles for k = 0.5 are independent switch-model anchors where HOGA is unresolved."});
exportFigure(f,root,'Fig03_capacitance_ratio',D,meta);

% ------------------------------------------------------------------- 图4/图5
V=0:50:800;F=1:.1:2;D=table();
for field=["Io_A","Im_A"]
    Z=nan(numel(F),numel(V));P=Z;opened=false(size(Z));st=strings(size(Z));
    for j=1:numel(F)
        for m=1:numel(V)
            at=find(abs(T.fn-F(j))<1e-6 & abs(T.Vo_V-V(m))<1e-6 & abs(T.k_delta-.2)<1e-6,1);
            if isempty(at)||~T.accepted(at),continue;end
            Z(j,m)=T.(field)(at);P(j,m)=T.minimum_comm_margin_A(at);
            opened(j,m)=contains(T.status(at),'OPEN_');st(j,m)=T.status(at);
        end
    end
    draw=Z;
    if field=="Io_A",draw(draw<1e-8)=NaN;end
    f=paperFigure(17.8,12.6);ax=axes(f,'Position',[.10 .215 .66 .695]);hold(ax,'on');
    % The map is rendered as an explicit true-colour image so that a cell can only
    % carry one of three meanings: solved value (colour), all-blocked family (pale
    % blue + x) or no accepted solution (neutral grey). No colormap sentinel is used.
    ve=[0 25:50:775 800]*gscale;fe=[1 1.05:.1:1.95 2];Mv=V*gscale;
    positive=draw(isfinite(draw)&draw>0);vmax=max(positive);vmin=min(positive);
    if isempty(positive),vmin=0;vmax=1;end
    span=max(vmax-vmin,1e-12);cmap=turbo(256);
    openPadded=[opened opened(:,end);opened(end,:) opened(end,end)];
    drawPadded=[draw draw(:,end);draw(end,:) draw(end,end)];
    RGB=zeros([size(drawPadded) 3]);
    for i=1:size(drawPadded,1)
        for j=1:size(drawPadded,2)
            v=drawPadded(i,j);
            if isfinite(v)                       % solved value, including the blocked family in the I_m map
                idx=1+round(255*min(max((v-vmin)/span,0),1));colour=cmap(idx,:);
            elseif openPadded(i,j)               % blocked family without a plotted output current
                colour=[.79 .85 .92];
            else                                 % no accepted periodic solution
                colour=[.80 .80 .80];
            end
            RGB(i,j,:)=colour;
        end
    end
    image(ax,ve,fe,RGB);set(ax,'YDir','normal');
    for j=1:numel(ve) % cell lattice
        line(ax,[ve(j) ve(j)],[1 2],'Color',[.93 .93 .93],'LineWidth',.4,'HandleVisibility','off');
    end
    for i=1:numel(fe)
        line(ax,[0 Mmax],[fe(i) fe(i)],'Color',[.93 .93 .93],'LineWidth',.4,'HandleVisibility','off');
    end
    cbax=axes(f,'Position',[.795 .215 .020 .695]);
    bar=repmat(reshape(cmap,[1 256 3]),[2 1 1]);
    image(cbax,[0 1],[0 1],bar);
    set(cbax,'YDir','normal','XTick',[],'YAxisLocation','right','FontSize',9);
    cbax.YTick=linspace(0,1,6);cbax.YTickLabel=compose('%.3g',linspace(vmin,vmax,6));
    ylabel(cbax,currentLabel(field),'FontSize',9);
    if any(P(isfinite(P))>0)&&any(P(isfinite(P))<0)
        [~,boundary]=contour(ax,Mv,F,P,[0 0],'k--','LineWidth',1.3);boundary.HandleVisibility='off';
    end
    [MM,FF]=meshgrid(Mv,F);
    if any(opened(:)),plot(ax,MM(opened),FF(opened),'kx','MarkerSize',4.5,'LineWidth',.9);end
    set(ax,'Layer','top');
    xlabel(ax,gainLabel);ylabel(ax,'Normalized switching frequency f_n = f_s/f_r');
    xlim(ax,[0 Mmax]);ylim(ax,[1 2]);title(ax,'k = 0.2; one cell per solved grid point');
    if field=="Io_A"
        note(f,{"Colour: accepted charging solution (I_o > 0). Light blue cell with x: all-blocked periodic family (I_o = 0, reachability not proven).", ...
            "Light grey cell: unresolved or not sampled. Dashed: zero contour of the minimum commutation-current margin between samples - necessary polarity only."});
    else
        note(f,{"Colour: accepted periodic solution (stress is shown even when I_o = 0). x: all-blocked periodic family, reachability not proven.", ...
            "Light grey cell: unresolved or not sampled. Dashed: zero contour of the minimum commutation-current margin between samples - necessary polarity only."});
    end
    if field=="Io_A",file='Fig04_Io_operating_map';else,file='Fig05_Im_stress_map';end
    D=[D;mapRows(V,F,Z,P,opened,st,string(field),gscale)]; %#ok<AGROW>
    exportFigure(f,root,file,D(strcmp(D.field,string(field)),:),meta);
end

% ---------------------------------------------------------------------- 图7
f=paperFigure(17.8,12.4);ax=axes(f,'Position',[.115 .225 .70 .645]);hold(ax,'on');
markers={'o','s','^','d'};volts=[100 400 600 800];D=table();
for j=1:4
    part=T(T.accepted & T.CCM & T.Io_A>1e-8 & abs(T.k_delta-.2)<1e-6 & abs(T.Vo_V-volts(j))<1e-6,:);
    part=sortrows(part,'fn');
    if height(part)>1
        plot(ax,part.Io_A,part.Im_A,'-','Color',[.72 .72 .72],'LineWidth',.8,'HandleVisibility','off');
    end
    scatter(ax,part.Io_A,part.Im_A,42,part.fn,markers{j},'filled','DisplayName',sprintf('V_o = %g V',volts(j)));
    if ~isempty(part)
        D=[D;table(repmat("Vo="+volts(j),height(part),1),part.Vo_V,part.M,part.fn,part.Io_A,part.Im_A,part.Irms_A, ...
            'VariableNames',{'series','Vo_V','M','fn','Io_A','Im_A','Irms_A'})]; %#ok<AGROW>
    end
end
colormap(ax,turbo(256));clim(ax,[1 2]);cb=colorbar(ax);cb.Title.String='f_n';
xlabel(ax,'Average output current I_o (A)');ylabel(ax,'Maximum resonant-current peak I_m (A)');
grid(ax,'on');xlim(ax,[min(D.Io_A)-.05 max(D.Io_A)+.08]);
legend(ax,'Location','northwest','FontSize',9);title(ax,'Sampled I_o / I_m relation at fixed V_o, k = 0.2');
note(f,{"Each marker is one accepted CCM node; the spread at fixed V_o is produced by f_n alone. M = V_o/(nV_{in}): the four sections are M = 0.5, 2, 3, 4.", ...
    "No device current limit or power limit is imposed; these samples are not a universal design boundary."});
exportFigure(f,root,'Fig07_output_stress_tradeoff',D,meta);

% ---------------------------------------------------------------------- 图8
f=paperFigure(17.8,12.4);ax=axes(f,'Position',[.115 .225 .80 .645]);hold(ax,'on');C=lines(3);D=table();H=gobjects(1,0);
for j=1:3
    fnv=[1.4 1.5 1.6];part=T(abs(T.fn-fnv(j))<1e-6 & abs(T.k_delta-.2)<1e-6 & T.Vo_V>=450 & T.Vo_V<=650,:);
    H(end+1)=plotBranch(ax,part,'Im_A',C(j,:),sprintf('f_n = %.2f',fnv(j))); %#ok<AGROW>
    D=[D;seriesRows(part,sprintf('f_n=%.2f',fnv(j)))]; %#ok<AGROW>
end
xlabel(ax,gainLabel);ylabel(ax,'Maximum resonant-current peak I_m (A)');
grid(ax,'on');xlim(ax,[450 650]*gscale);legend(ax,H,'Location','northwest','FontSize',9);
title(ax,'Current-peak intersection check near the 550 V operating point, k = 0.2');
note(f,{"Markers are accepted HOGA solves. Only sign changes of I_m(f_n=1.4)-I_m(f_n=1.5) and I_m(1.4)-I_m(1.6) between adjacent verified nodes are reported;", ...
    "no root was interpolated and no crossing is declared outside a verified bracket. M = 2.25-3.25 corresponds to V_o = 450-650 V."});
exportFigure(f,root,'Fig08_crossing_check',D,meta);

% ---------------------------------------------------------------------- 图9
f=paperFigure(17.8,12.4);ax=axes(f,'Position',[.115 .225 .80 .645]);hold(ax,'on');
kk=linspace(.1,1,401);ratio=sqrt(1+1./(3*kk));H=gobjects(1,3);
H(1)=plot(ax,kk,ratio,'k-','DisplayName','f_{open}/f_r = sqrt(1 + 1/(3k))');
H(2)=plot(ax,ks_plot(),sqrt(1+1./(3*ks_plot())),'o','MarkerSize',6, ...
    'MarkerFaceColor',[.13 .42 .66],'MarkerEdgeColor',[.13 .42 .66],'DisplayName','studied k values');
H(3)=yline(ax,1.4,'--','f_n = 1.40','LabelHorizontalAlignment','left','DisplayName','scan frequency');
xlabel(ax,'Capacitance ratio k = C_{p,\Delta}/C_s');ylabel(ax,'Open-circuit resonance f_{open}/f_r');grid(ax,'on');
xlim(ax,[.1 1]);ylim(ax,[1 2.2]);legend(ax,H,'Location','northeast','FontSize',9);
title(ax,'No-load resonance location versus capacitance ratio');
note(f,{"Derived from the same balanced delta network: the star-equivalent parallel capacitance is 3k C_s.", ...
    "f_open is a no-load resonance, not a loaded operating boundary; it only explains why the useful f_n window moves with k."});
D=table(kk(:),ratio(:),'VariableNames',{'k_delta','f_open_over_fr'});
exportFigure(f,root,'Fig09_capacitance_resonance_shift',D,meta);

% ------------------------------------------------------------ switching validation
files=dir(fullfile(root,'validation','*.mat'));count=0;
for index=1:numel(files)
    d=load(fullfile(files(index).folder,files(index).name));
    if ~isfield(d,'record')||~isfield(d,'s')||~isfield(d,'cfg')||~isfield(d,'trace'),continue;end
    s=d.s;cfgv=d.cfg;trace=d.trace;fs=cfgv.fs_Hz;
    tau=linspace(0,1,2049).';time=(cfgv.cycles-1+tau)/fs;
    [state,j2]=lcc3v2Evaluate(s,mod(tau,1));g=lcc3v2Geometry();reference=state(:,1:2)*g.U';
    expectedIo=sum(max(j2*g.U',0),2);
    f=paperFigure(17.8,20);tl=tiledlayout(f,4,1,'TileSpacing','compact','Padding','compact');
    tl.OuterPosition=[0 .05 1 .94];D=table();
    for phase=1:4
        ax=nexttile(tl);hold(ax,'on');
        if phase<=3
            fields={'ia_A','ib_A','ic_A'};sig=trace.(fields{phase});ref=reference(:,phase);
            label=sprintf('i_{r,%c} (A)',char('a'+phase-1));
        else
            sig=trace.Io_A;ref=expectedIo;label='i_o (A)';
        end
        measured=interp1(sig.time,sig.data,time,'linear');
        plot(ax,tau,ref,'k--','LineWidth',1,'DisplayName','HOGA reconstruction');
        plot(ax,tau,measured,'Color',[.12 .43 .68],'LineWidth',.9,'DisplayName','Simulink');
        ylabel(ax,label);grid(ax,'on');xlim(ax,[0 1]);
        D=[D;table(tau,ref,measured,repmat(string(label),numel(tau),1), ...
            'VariableNames',{'t_over_Ts','HOGA_A','Simulink_A','signal'})]; %#ok<AGROW>
        if phase==1,legend(ax,'Location','southeast','NumColumns',1,'FontSize',8);end
        if phase==4,xlabel(ax,'Normalized time t/T_s');end
    end
    title(tl,sprintf('V_o = %g V, f_n = %.3f, k = %.3g; I_o error %.4g%%, I_m error %.4g%%', ...
        cfgv.Vo_initial_V,cfgv.fn,cfgv.k_delta,d.record.Io_error_percent,d.record.Im_error_percent));
    note(f,sprintf(['Near-frozen output capacitor (%g x actual); last 8 of %d cycles; voltage drift %.4g%%, ', ...
        'cycle-to-cycle change %.4g%%. Recorded acceptance: %d.'],cfgv.output_Co_scale,cfgv.cycles, ...
        d.record.Vo_drift_percent,d.record.periodic_change_percent,d.record.accepted));
    [~,nm]=fileparts(files(index).name);exportFigure(f,root,['Validation_' nm],D,meta);count=count+1;
end

prov=meta;prov.exported_figures=count+9;
prov.export_formats={'PDF vector','SVG vector','PNG 600 dpi','MATLAB FIG','MAT/CSV per figure'};
prov.figure_data_folder='figures/data';
fid=fopen(fullfile(root,'figures','figure_provenance.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(prov,PrettyPrint=true));fclose(fid);
fprintf('PAPER_FIGURES_COMPLETE figures=%d\n',count+9);
end

% ======================================================================= helpers
function h=rowMajor(h,ncols)
% MATLAB fills legend columns top-down; reorder so rows read in the plotted order.
n=numel(h);rows=ceil(n/ncols);order=zeros(1,n);
for r=1:rows
    for j=1:ncols
        position=(j-1)*rows+r;target=(r-1)*ncols+j;
        if position<=n && target<=n,order(position)=target;end
    end
end
order=order(order>0);
if numel(order)==n,h=h(order);end
end

function s=ks_plot()
s=[.1 .2 .35 .5 .8 1];
end

function styleFigure()
set(groot,'defaultAxesFontName','Times New Roman','defaultTextFontName','Times New Roman', ...
    'defaultAxesFontSize',10,'defaultTextFontSize',10,'defaultAxesLineWidth',.7, ...
    'defaultLineLineWidth',1.25,'defaultFigureColor','w','defaultLegendBox','off', ...
    'defaultAxesTickDir','out','defaultAxesLayer','top','defaultAxesBox','on');
end

function f=paperFigure(width,height)
f=figure('Visible','off','Units','centimeters','Position',[2 2 width height], ...
    'PaperUnits','centimeters','PaperSize',[width height],'PaperPosition',[0 0 width height], ...
    'Renderer','painters','Color','w');
end

function label=currentLabel(field)
switch string(field)
    case 'Io_A',label='Average output current I_o (A)';
    case 'Im_A',label='Maximum resonant-current peak I_m (A)';
    otherwise,label='Maximum phase RMS current I_{rms} (A)';
end
end

function lim=autoLimit(D,field)
if isempty(D),lim=[0 1];return;end
y=D.(char(field));y=y(isfinite(y));
if isempty(y),lim=[0 1];return;end
hi=max(y)*1.12;lo=min(0,min(y));
if strcmp(char(field),'Io_A'),lo=-.04*hi;end % keep the I_o = 0 family visible above the axis
if hi<=lo,hi=lo+1;end
lim=[lo hi];
end

function h=plotBranch(ax,T,field,color,label,showLabel)
if nargin<6,showLabel=true;end
if isempty(T)
    h=plot(ax,NaN,NaN,'-o','Color',color,'MarkerSize',3,'MarkerFaceColor',color,'LineWidth',1.3);
    if ~showLabel,h.HandleVisibility='off';else,h.DisplayName=label;end
    return
end
T=sortrows(T,'M');
charging=T.accepted & T.Io_A>1e-8;opened=T.accepted & contains(T.status,'OPEN_');
y=T.(field);y(~charging)=NaN;
h=plot(ax,T.M,y,'-o','Color',color,'MarkerSize',3,'MarkerFaceColor',color,'LineWidth',1.3);
if showLabel,h.DisplayName=label;else,h.HandleVisibility='off';end
y=T.(field);y(~opened)=NaN;
if any(opened)
    plot(ax,T.M,y,':','Color',.55*color+.45*[1 1 1],'LineWidth',1.0,'HandleVisibility','off');
end
dcm=charging & ~T.CCM;
if any(dcm),plot(ax,T.M(dcm),T.(field)(dcm),'^','Color',color,'MarkerSize',4,'MarkerFaceColor','w','HandleVisibility','off');end
end

function D=seriesRows(T,label)
if isempty(T)
    D=table(strings(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1),zeros(0,1), ...
        strings(0,1),logical(zeros(0,1)),strings(0,1), ...
        'VariableNames',{'series','Vo_V','M','fn','k_delta','Io_A','Im_A','Irms_A','status','CCM','node_class'});
    return
end
cls=repmat("unresolved",height(T),1);
cls(T.accepted & T.Io_A>1e-8)="charging";
cls(T.accepted & contains(T.status,'OPEN_'))="open_family";
D=table(repmat(string(label),height(T),1),T.Vo_V,T.M,T.fn,T.k_delta,T.Io_A,T.Im_A,T.Irms_A, ...
    string(T.status),T.CCM,cls, ...
    'VariableNames',{'series','Vo_V','M','fn','k_delta','Io_A','Im_A','Irms_A','status','CCM','node_class'});
end

function D=mapRows(V,F,Z,P,opened,st,field,gscale)
[nF,nV]=size(Z);series=strings(nF*nV,1);vo=zeros(nF*nV,1);mm=zeros(nF*nV,1);fnv=zeros(nF*nV,1);
val=zeros(nF*nV,1);margin=zeros(nF*nV,1);op=false(nF*nV,1);status=strings(nF*nV,1);idx=0;
for j=1:nF
    for m=1:nV
        idx=idx+1;series(idx)=field;vo(idx)=V(m);mm(idx)=V(m)*gscale;fnv(idx)=F(j);val(idx)=Z(j,m);
        margin(idx)=P(j,m);op(idx)=opened(j,m);status(idx)=st(j,m);
    end
end
D=table(series,vo,mm,fnv,val,margin,op,status,'VariableNames', ...
    {'field','Vo_V','M','fn','value','minimum_comm_margin_A','open_family','status'});
end

function note(f,lines)
if ischar(lines),lines={lines};end
annotation(f,'textbox',[.02 .012 .96 .060],'String',lines,'EdgeColor','none', ...
    'FontSize',7.2,'Color',[.28 .28 .28],'VerticalAlignment','bottom','Interpreter','tex');
end

function exportFigure(f,root,name,D,meta)
folder=fullfile(root,'figures');dataFolder=fullfile(folder,'data');
savefig(f,fullfile(folder,[name '.fig']));
print(f,fullfile(folder,[name '.pdf']),'-dpdf','-painters');
print(f,fullfile(folder,[name '.svg']),'-dsvg','-painters');
print(f,fullfile(folder,[name '.png']),'-dpng','-r600','-painters');
if nargin>3 && ~isempty(D)
    writetable(D,fullfile(dataFolder,[name '.csv']),'Encoding','UTF-8');
    figure_data=D;figure_meta=meta; %#ok<NASGU>
    save(fullfile(dataFolder,[name '.mat']),'figure_data','figure_meta','-v7');
end
close(f);fprintf('FIGURE %s (%d rows)\n',name,height(D));
end

function v=toLogical(x)
if islogical(x),v=x;return;end
if isnumeric(x),v=x~=0;return;end
s=lower(string(x));v=s=="true"|s=="1"|s=="yes";
end
