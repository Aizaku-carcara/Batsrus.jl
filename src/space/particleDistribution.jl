# Distribution plot in a large PIC domain.
#
#
# Hongyang Zhou, hyzhou@umich.edu 01/30/2020

using VisAna, PyPlot, Printf, LinearAlgebra, Statistics

## Parameters
const cAlfven = 253       # average Alfven speed in G8, [km/s]
const me = 9.10938356e-31 # electron mass, [kg]
const mp = 1.6726219e-27  # proton mass, [kg]
const mi = 14             # average ion mass [amu]
const nBox = 9            # number of box regions

"""
	dist_select(fnameParticle; ParticleType='e', dir=".")

Select particle in regions.
`ParticleType` in ['e','i'].
xC, yC, zC are the central box center position.
"""
function dist_select(fnameParticle, xC=-1.90, yC=0.0, zC=-0.1,
   xL=0.005, yL=0.2, zL=0.07; ParticleType='e',
   dir="/Users/hyzhou/Documents/Computer/Julia/BATSRUS/VisAnaJulia/",)

   if ParticleType == 'i'
      !occursin("region0_2", fnameParticle) && @error "Check filename!"
   elseif ParticleType == 'e'
      !occursin("region0_1", fnameParticle) && @error "Check filename!"
   end

   fnameField = "3d_var_region0_0_"*fnameParticle[end-22:end]

   # Classify particles based on locations
   region = Array{Float32,2}(undef,6,nBox)
   region[:,1] = [xC-xL*3/2, xC-xL/2,   yC-yL/2, yC+yL/2, zC+zL/2,   zC+zL*3/2]
   region[:,2] = [xC-xL/2,   xC+xL/2,   yC-yL/2, yC+yL/2, zC+zL/2,   zC+zL*3/2]
   region[:,3] = [xC+xL/2,   xC+xL*3/2, yC-yL/2, yC+yL/2, zC+zL/2,   zC+zL*3/2]
   region[:,4] = [xC-xL*3/2, xC-xL/2,   yC-yL/2, yC+yL/2, zC-zL/2,   zC+zL/2]
   region[:,5] = [xC-xL/2,   xC+xL/2,   yC-yL/2, yC+yL/2, zC-zL/2,   zC+zL/2]
   region[:,6] = [xC+xL/2,   xC+xL*3/2, yC-yL/2, yC+yL/2, zC-zL/2,   zC+zL/2]
   region[:,7] = [xC-xL*3/2, xC-xL/2,   yC-yL/2, yC+yL/2, zC-zL*3/2, zC-zL/2]
   region[:,8] = [xC-xL/2,   xC+xL/2,   yC-yL/2, yC+yL/2, zC-zL*3/2, zC-zL/2]
   region[:,9] = [xC+xL/2,   xC+xL*3/2, yC-yL/2, yC+yL/2, zC-zL*3/2, zC-zL/2]

   particle = [Array{Float32}(undef, 3, 0) for _ in 1:nBox]

   head, data = readdata(fnameParticle, dir=dir)

   x = @view data[1].x[:,:,:,1]
   y = @view data[1].x[:,:,:,2]
   z = @view data[1].x[:,:,:,3]

   ux_ = findfirst(x->x=="ux", head[1][:wnames])
   uy_ = findfirst(x->x=="uy", head[1][:wnames])
   uz_ = findfirst(x->x=="uz", head[1][:wnames])

   ux = @view data[1].w[:,:,:,ux_]
   uy = @view data[1].w[:,:,:,uy_]
   uz = @view data[1].w[:,:,:,uz_]

   for ip = 1:length(x)
      for iR = 1:nBox
         if region[1,iR] < x[ip] < region[2,iR] &&
            region[3,iR] < y[ip] < region[4,iR] &&
            region[5,iR] < z[ip] < region[6,iR]

            particle[iR] = hcat(particle[iR], [ux[ip]; uy[ip]; uz[ip]])
            break
         end
      end
   end
   return region, particle
end

"""
	dist_plot(region, particle, ParticleType='i', PlotVType=1)

Velocity distribution plot in 9 regions.
`PlotVType`: 1: uy-ux; 2: ux-uz; 3:uy-uz; 4:u⟂O-u⟂I; 5:u⟂I-u∥; 5:u⟂O-u∥
"""
function dist_plot(region, particle, ParticleType='i', PlotVType=1; dir=".",
   fnameField::String, nbin=60, fs=10)

   if ParticleType == 'i'
      binRange = [[-3.,3.], [-3.,3.]]
   elseif ParticleType == 'e'
      binRange = [[-10.,12.], [-10.,10.]]
   end

   figure(figsize=(11,6))
   for iB = 1:nBox
      if PlotVType ≤ 3
         ux = particle[iB][1,:] ./ cAlfven
         uy = particle[iB][2,:] ./ cAlfven
         uz = particle[iB][3,:] ./ cAlfven
      else
         dBx, dBy, dBz = GetMeanField(fnameField, region[:,iB]; dir=dir)

         dPar = [dBx; dBy; dBz] # Parallel direction
         dPerpI = cross([0; -1; 0], dPar) # Perpendicular direction in-plane
         dPerpO = cross(dPar, dPerpI) # Perpendicular direction out-of-plane

         uPar = transpose(particle[iB][1:3,:])*dPar ./ cAlfven
         uPerpI = transpose(particle[iB][1:3,:])*dPerpI ./ cAlfven
         uPerpO = transpose(particle[iB][1:3,:])*dPerpO ./ cAlfven
      end

      ax = subplot(3,4,iB+ceil(iB/3))
      if PlotVType==1
         h = hist2D(uy, ux, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      elseif PlotVType==2
         h = hist2D(ux, uz, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      elseif PlotVType==3
         h = hist2D(uy, uz, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      elseif PlotVType==4
         h = hist2D(uPerpO, uPerpI, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      elseif PlotVType==5
         h = hist2D(uPerpI, uPar, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      elseif PlotVType==6
         h = hist2D(uPerpO, uPar, bins=nbin,
            norm=matplotlib.colors.LogNorm(),density=true, range=binRange)
      else
         @error "Unknown PlotVType!"
      end
      grid(true)
      axis("equal")

      if PlotVType==1
         xlabel(L"u_y",fontsize=fs)
         ylabel(L"u_x",fontsize=fs)
      elseif PlotVType==2
         xlabel(L"u_x",FontSize=fs)
         ylabel(L"u_z",FontSize=fs)
      elseif PlotVType==3
         xlabel(L"u_y",FontSize=fs)
         ylabel(L"u_z",FontSize=fs)
      elseif PlotVType==4
         xlabel(L"u_{\perp Out}",fontsize=fs)
         ylabel(L"u_{\perp In}",fontsize=fs)
      elseif PlotVType==5
         xlabel(L"u_{\perp In}",FontSize=fs)
         ylabel(L"u_\parallel",FontSize=fs)
      elseif PlotVType==6
         xlabel(L"u_{\perp Out}",FontSize=fs)
         ylabel(L"u_\parallel",FontSize=fs)
      end
      title(@sprintf("%d, x[%3.3f,%3.3f], z[%3.3f,%3.3f]",iB,region[1,iB],
         region[2,iB],region[5,iB],region[6,iB]))
      colorbar()
      plt.set_cmap("hot")
      #clim(1e-2,10^0.3)

      if ParticleType == 'e'
         str = "electron"
      elseif ParticleType == 'i'
         str = "ion"
      end
      text(0.05,0.05,str, FontSize=fs, transform=ax.transAxes)
   end

end

"""
	GetMeanField(fnameField, limits; dir=".")

GetMeanField Get the average field direction in limited region.
   * Extract the average field from field data
"""
function GetMeanField(fnameField::String, limits; dir=".")

   # Get the average field direction in limited region
   head, data = readdata(fnameField, dir=dir)

   x = data[1].x[:,:,:,1]
   y = data[1].x[:,:,:,2]
   z = data[1].x[:,:,:,3]

   bx_ = findfirst(x->x=="Bx", head[1][:wnames])
   by_ = findfirst(x->x=="By", head[1][:wnames])
   bz_ = findfirst(x->x=="Bz", head[1][:wnames])

   Bx = @view data[1].w[:,:,:,bx_]
   By = @view data[1].w[:,:,:,by_]
   Bz = @view data[1].w[:,:,:,bz_]

   xnew, ynew, znew, BxNew, ByNew, BzNew = subvolume(x,y,z, Bx,By,Bz, limits)

   # Average over the selected volume
   B̄x, B̄y, B̄z = mean(BxNew), mean(ByNew), mean(BzNew)

   # Normalize vector
   Length = √(B̄x^2 + B̄y^2 + B̄z^2)
   dBx, dBy, dBz = B̄x/Length, B̄y/Length, B̄z/Length

   return dBx, dBy, dBz
end



function plotExCut(fnameField::String, region, xC, yC, zC, xL, yL, zL;
   dir="/Users/hyzhou", fs=16)

   plotrange = [xC-xL*16, xC+xL*16, zC-zL*5, zC+zL*5]
   # Sample region plot over contour
   head, data = readdata(fnameField, dir=dir)

   bx_ = findfirst(x->x=="Bx", head[1][:wnames])
   bz_ = findfirst(x->x=="Bz", head[1][:wnames])

   Bx = @view data[1].w[:,:,:,bx_]
   Bz = @view data[1].w[:,:,:,bz_]

   subplot(3,4,(1,9))
   cutplot(data[1],head[1],"Ex",cut='y',cutPlaneIndex=128,plotrange=plotrange)
   colorbar()
   axis("scaled")
   plt.set_cmap("RdBu_r")
   clim(-9e4,9e4)

   streamslice(data[1],head[1],"Bx;Bz",cut='y',cutPlaneIndex=128, color="k",
      density=1.0, plotrange=plotrange)

   xlabel(L"x [R_G]", fontsize=fs)
   ylabel(L"z [R_G]", fontsize=fs)
   title(L"Ex [\mu V/m]")

   for iB = 1:nBox
      rect = matplotlib.patches.Rectangle( (region[1,iB], region[5,iB]),
      region[2,iB]-region[1,iB], region[6,iB]-region[5,iB],
      ec="r", lw=1.2, fill=false) # facecolor="none"
      ax = gca()
      ax.add_patch(rect)
   end

   #=
   # streamline function requires the meshgrid format strictly
   s = streamslice(cut1",cut2",Bx",Bz",1,"linear")
   for is = 1:length(s)
   s(is).Color = "k"
   s(is).LineWidth = 1.3
   end
   =#
end

dir = "/Users/hyzhou"
fnameField = "3d_var_region0_0_t00001640_n00020369.out"
PType = 'i'
PlotVType = 3

if PType == 'e'
   fnameParticle = "cut_particles0_region0_1_t00001640_n00020369.out"
elseif PType == 'i'
   fnameParticle = "cut_particles1_region0_2_t00001640_n00020369.out"
end


# Define regions
xC, yC, zC = -1.90, 0.0, -0.25
xL, yL, zL = 0.008, 0.2, 0.03 # box length in x,y,z

@time region, particle = dist_select(
   fnameParticle, xC, yC, zC, xL, yL, zL,
   dir=dir, ParticleType=PType)
@time dist_plot(region, particle, PType, PlotVType; dir=dir, fnameField=fnameField)

@time plotExCut(fnameField, region, xC,yC,zC,xL,yL,zL, dir=dir)
